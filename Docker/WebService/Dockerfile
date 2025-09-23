# syntax=docker/dockerfile:1.7-labs

FROM alpine as intermediate
LABEL stage=intermediate
RUN apk update && apk add --no-cache git
RUN git clone --depth 1 --branch master https://github.com/racai-ai/saroj.git /saroj

FROM php:7.4-apache
ARG DEBIAN_FRONTEND=noninteractive

# System stuff + locale (aceleași pachete)
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update -qq && apt-get install -y -qq \
      tar zip unzip curl wget mc locales \
      gcc g++ make automake autoconf bison flex zlib1g zlib1g-dev \
      libffi-dev libssl-dev libbz2-dev libreadline-dev libgdbm-dev uuid uuid-dev \
      xz-utils libsqlite3-dev ncurses-dev \
    && echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Build Python 3.11 (aceeași versiune/opțiuni), dar mai compact și cu paralelism dinamic
RUN set -eux; \
    mkdir -p /programs /programs_build/python_build; \
    cd /programs_build/python_build; \
    wget -q https://github.com/python/cpython/archive/v3.11.4.tar.gz; \
    tar -zxf v3.11.4.tar.gz; \
    cd cpython-3.11.4; \
    ./configure --prefix=/programs/python-3.11 --enable-optimizations; \
    make -j"$(nproc)"; \
    make install; \
    cd /; rm -rf /programs_build

# Build Python 3.7
RUN set -eux; \
    mkdir -p /programs_build/python_build; \
    cd /programs_build/python_build; \
    wget -q https://github.com/python/cpython/archive/v3.7.4.tar.gz; \
    tar -zxf v3.7.4.tar.gz; \
    cd cpython-3.7.4; \
    ./configure --prefix=/programs/python-3.7; \
    make -j"$(nproc)"; \
    make install; \
    cd /; rm -rf /programs_build

# Creează venv-uri
RUN /programs/python-3.11/bin/python3 -m venv /venv \
 && /programs/python-3.7/bin/python3  -m venv /venv-3.7

# Copiem DOAR requirements mai întâi, ca să cacheze instalarea pip
COPY --from=intermediate /saroj/WebServiceModules/TextExtractor/requirements.txt /tmp/tx-req.txt
COPY --from=intermediate /saroj/WebServiceModules/RNER/requirements.txt        /tmp/rner-req.txt

# Instalează deps Py3.11 cu NumPy pin-uit (fără să schimbe pachetele)
RUN --mount=type=cache,target=/root/.cache/pip \
    /venv/bin/pip3 install -U pip setuptools wheel && \
    /venv/bin/pip3 install "numpy==1.26.4" && \
    /venv/bin/pip3 install -r /tmp/tx-req.txt && \
    /venv/bin/pip3 install torch --index-url https://download.pytorch.org/whl/cpu && \
    /venv/bin/pip3 install rwpt scikit-learn

# Instalează deps Py3.7 cu NumPy pin-uit
RUN --mount=type=cache,target=/root/.cache/pip \
    /venv-3.7/bin/pip3 install -U pip setuptools wheel && \
    /venv-3.7/bin/pip3 install "numpy==1.21.6" && \
    /venv-3.7/bin/pip3 install -r /tmp/rner-req.txt && \
    /venv-3.7/bin/pip3 install torch==1.13.1+cpu -f https://download.pytorch.org/whl/cpu/torch_stable.html && \
    /venv-3.7/bin/pip3 install rwpt "scikit-learn==1.0.2" "flask<=2.2.5" "spacy==2.3.7"

# După ce s-au instalat deps, copiem restul modulelor (nu mai invalidează cache-ul pip la fiecare commit)
COPY --from=intermediate /saroj/WebServiceModules/ /modules/

# Java (identic)
COPY openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb /
RUN apt-get update -qq && apt install -y -qq /openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb \
 && rm -rf /var/lib/apt/lists/* /openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb

# Rules & site
COPY --from=intermediate /saroj/Rules/ /Rules/
COPY --from=intermediate /saroj/WebService/web/ /site/
RUN chown -R www-data:www-data /site/
COPY conf/apache2.conf /etc/apache2/
COPY conf/php.ini /usr/local/etc/php/
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_PID_FILE=/var/run/apache2.pid

# Entrypoint
COPY docker/entrypoint.sh /
RUN chmod a+rx /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/entrypoint.sh"]
