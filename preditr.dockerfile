FROM fvasquezcastro/preditr_base:v7_amd64

RUN mkdir -p /app

WORKDIR /app

COPY . /app

RUN chmod +x PrEditR.R

EXPOSE 3838

ENTRYPOINT ["R", "-e", "shiny::runApp('/app', host='0.0.0.0', port=3838)"]