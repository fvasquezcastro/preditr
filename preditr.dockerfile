FROM fvasquezcastro/preditr_base:v8_amd64

RUN mkdir -p /app

WORKDIR /app

COPY . /app

RUN chmod +x PrEditR.R docker-entrypoint.sh

EXPOSE 3838

# No args -> Shiny app; args -> CLI (see docker-entrypoint.sh).
ENTRYPOINT ["/app/docker-entrypoint.sh"]