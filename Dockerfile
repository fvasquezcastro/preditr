FROM fvasquezcastro/preditr_base:v1_amd64
#FROM fvasquezcastro/r-devel:4.4.1_arm64

WORKDIR /home

COPY . /home

RUN mkdir /home/shiny_tmp

ENV PATH="/home:${PATH}"

RUN echo "setwd('/home')" >> /etc/R/Rprofile.site

#RUN Rscript installResources.R #Already installed in preditr_base

RUN chmod +x index_genome.R && chmod +x PrEditR.R

EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/home', host = '0.0.0.0', port = 3838)"]

