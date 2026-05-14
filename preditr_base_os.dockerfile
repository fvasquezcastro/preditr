FROM bioconductor/bioconductor_docker:3.19

RUN apt-get update -qq && apt-get -y --no-install-recommends install \
    libxml2-dev \
    glpk-utils \
    libssh-dev \
    libtiff-dev \
    libbz2-dev \
    gdal-bin \
    libudunits2-dev \
    libgdal-dev \
    libcurl4-gnutls-dev \
    zlib1g-dev \
    gdebi-core \
    wget

RUN mkdir /app
COPY installResources.R /app
WORKDIR /app

RUN mkdir -p "/root/.R" && \
    echo 'options(repos = c(CRAN = "https://p3m.dev/cran/__linux__/jammy/latest"))' > /root/.Rprofile && \
    Rscript installResources.R
