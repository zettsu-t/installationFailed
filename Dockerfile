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
