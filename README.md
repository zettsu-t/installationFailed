# A tmpfs with the noexec flag causes installation failures for R packages

This repository reproduces an error that occurred in installing an R package. It is hard to identify root causes when `R CMD check` says "Could not find tools necessary to compile a package" and I explain what happens here.

## Environment to reproduce errors

We create a Docker image from the Dockerfile below. To make a minimum environment to reproduce errors, we use ubuntu:focal as a parent image instead of rocker/tidyverse. I ran and confirmed code in this repository on Windows 10 + WSL2 + R 3.6.3.

```
FROM ubuntu:focal

ENV TZ=Asia/Tokyo
RUN apt-get update && apt-get install -y tzdata
RUN apt-get install -y r-base
RUN apt-get install -y wget gdebi-core
RUN wget https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2021.09.1-372-amd64.deb
RUN gdebi --non-interactive rstudio-server-2021.09.1-372-amd64.deb

RUN apt-get install -y libssl-dev libcurl4-openssl-dev libxml2-dev
RUN R -e 'install.packages("remotes")'
RUN Rscript -e 'remotes::install_version("devtools")'

RUN adduser --disabled-password --gecos "" rstudio
RUN echo "rstudio:rstudio" | chpasswd
CMD rstudio-server start && tail -f < /dev/null
```

We write docker-compose.yml as below and set the exec flag to /tmp as a tmpfs explicitly.

```
version: '3'
services:
  installation_failed:
    build: .
    image: installation_failed
    ports:
      - 8787:8787
    tmpfs:
      - /tmp:exec
    volumes:
      - .:/home/rstudio/work
```

We build and start the Docker image and we can log on to an RStudio Server at http://example.com:8787/ (replace its hostname to an actual server like localhost) via a Web browser. A user name and its password are _rstudio_ as described in the Dockerfile.

``` bash
# possibly sudo is required
docker-compose -f docker-compose.yml build
docker-compose -f docker-compose.yml up -d
```

## tmpfs with the exec flag

We install the data.table package. It succeeds unless an HTTP proxy prohibits it.

``` r
install.packages("data.table")
library(data.table)
```

The pkgbuild package tells us whether we can build R packages. The result below says there is no problem.

``` r
pkgbuild::check_build_tools(debug = TRUE)
## Your system is ready to build packages!

pkgbuild::check_compiler(debug = TRUE)
## Trying to compile a simple C file
## Running /usr/lib/R/bin/R CMD SHLIB foo.c
## gcc -std=gnu99 -I"/usr/share/R/include" -DNDEBUG -fpic -g -O2 -fdebug-prefix-map=/build/r-base-jbaK_j/r-base-3.6.3=. -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g -c foo.c -o foo.o
## gcc -std=gnu99 -shared -L/usr/lib/R/lib -Wl,-Bsymbolic-functions -Wl,-z,relro -o foo.so foo.o -L/usr/lib/R/lib -lR
## [1] TRUE
```

## tmpfs with the noexec flag

We change `/tmp:exec` to `/tmp:noexec` in the docker-compose.yml and save as docker-compose-noexec.yml.

```
version: '3'
services:
  installation_failed:
    build: .
    image: installation_failed
    ports:
      - 8787:8787
    tmpfs:
      - /tmp:noexec
    volumes:
      - .:/home/rstudio/work
```

We launch the Docker with docker-compose-noexec.yml.

``` bash
# possibly sudo is required
docker-compose -f docker-compose.yml down
docker-compose -f docker-compose-noexec.yml up -d
```

We check whether we can build R packages again. The pkgbuild package finds build tools but fails a compilation.

``` r
pkgbuild::check_build_tools(debug = TRUE)
## Your system is ready to build packages!

pkgbuild::check_compiler(debug = TRUE)
## Trying to compile a simple C file
## Running /usr/lib/R/bin/R CMD SHLIB foo.c
## gcc -std=gnu99 -I"/usr/share/R/include" -DNDEBUG -fpic -g -O2 -fdebug-prefix-map=/build/r-base-jbaK_j/r-base-3.6.3=. -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g -c foo.c -o foo.o
## gcc -std=gnu99 -shared -L/usr/lib/R/lib -Wl,-Bsymbolic-functions -Wl,-z,relro -o foo.so foo.o -L/usr/lib/R/lib -lR
## Error: Failed to compile C code
```

Now we install the data.table package. It says "'configure' exists but is not executable_ and fails".

``` r
install.packages("data.table")

> install.packages("data.table")
## Installing package into '/home/rstudio/R/x86_64-pc-linux-gnu-library/3.6'
## (as 'lib' is unspecified)
## trying URL 'https://cloud.r-project.org/src/contrib/data.table_1.14.2.tar.gz'
## Content type 'application/x-gzip' length 5301817 bytes (5.1 MB)
## ==================================================
## downloaded 5.1 MB
##
## * installing *source* package 'data.table' ...
## ** package 'data.table' successfully unpacked and MD5 sums checked
## ** using staged installation
## ERROR: 'configure' exists but is not executable -- see the 'R Installation and Administration Manual'
## * removing '/home/rstudio/R/x86_64-pc-linux-gnu-library/3.6/data.table'
## Warning in install.packages :
##   installation of package 'data.table' had non-zero exit status
##
## The downloaded source packages are in
## 	'/tmp/RtmpatoM4r/downloaded_packages'
```

The error messages above show that building the data.table package in /tmp failed and  _configure_ is not executable but do not suggest that it is due to a noexec tmpfs. A similar discussion is in [GitHub Issues](https://github.com/r-lib/devtools/issues/32).

We can confirm /tmp is mounted as a tmpfs and used with the noexec flag.

``` bash
findmnt /tmp
## TARGET SOURCE FSTYPE OPTIONS
## /tmp   tmpfs  tmpfs  rw,nosuid,nodev,noexec,relatime
```

## Install a self-made R package

When we create an R package, we describe package dependencies in the Imports field in its DESCRIPTION. If we build a package that depends on the data.table package, it fails on a noexec tmpfs.

### tmpfs with the exec flag

1. Execute `install.packages("data.table")` in Console in RStudio
1. Open the Build tab in RStudio
1. Press the Check button to check the package and it completes
1. Install and Restart also succeeds

### tmpfs with the noexec flag

1. `install.packages("data.table")` fails and ignore it now
1. Open the Build tab in RStudio
1. Press the Check button to check the package and we get the error messages below

```
==> devtools::check(document = FALSE)

-- Building ------------------------------- installationfailedsample --
Setting env vars:
* CFLAGS    : -Wall -pedantic
* CXXFLAGS  : -Wall -pedantic
* CXX11FLAGS: -Wall -pedantic
-----------------------------------------------------------------------
v  checking for file '/home/rstudio/work/sample/DESCRIPTION' ...
-  preparing 'installationfailedsample':
v  checking DESCRIPTION meta-information ... OK
-  checking for LF line-endings in source and make files and shell scripts
-  checking for empty or unneeded directories
-  building 'installationfailedsample_0.1.0.tar.gz'

-- Checking ------------------------------- installationfailedsample --
Setting env vars:
* _R_CHECK_CRAN_INCOMING_REMOTE_: FALSE
* _R_CHECK_CRAN_INCOMING_       : FALSE
* _R_CHECK_FORCE_SUGGESTS_      : FALSE
* NOT_CRAN                      : true
Error: Could not find tools necessary to compile a package
Call `pkgbuild::check_build_tools(debug = TRUE)` to diagnose the problem.
Execution halted

Exited with status 1.
```

gcc and g++ are available and it leads `pkgbuild::check_build_tools(debug = TRUE)` to success. It is hard to understand that the noexec flag of /tmp is the root cause of the error when we read "Could not find tools necessary to compile a package".
