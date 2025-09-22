FROM alpine as intermediate
LABEL stage=intermediate
RUN apk update && apk add --no-cache git \
 && git clone --depth 1 --branch master https://github.com/racai-ai/saroj.git

FROM php:7.4-apache
ARG DEBIAN_FRONTEND=noninteractive
ARG MAKE_JOBS
ENV MAKE_JOBS=${MAKE_JOBS:-$(nproc)}

RUN set -eux; \
    apt-get update; \
    # System stuff
    apt-get install -y --no-install-recommends \
      tar zip unzip curl wget mc locales ca-certificates \
      gcc g++ make automake autoconf bison flex zlib1g zlib1g-dev \
      libffi-dev libssl-dev libbz2-dev libreadline-dev libgdbm-dev \
      uuid uuid-dev xz-utils libsqlite3-dev ncurses-dev; \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    rm -rf /var/lib/apt/lists/*
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Build Python
RUN set -eux; \
    mkdir -p /programs /programs_build/python_build; \
    cd /programs_build/python_build; \
    wget -q https://github.com/python/cpython/archive/v3.11.4.tar.gz; \
    tar -zxf v3.11.4.tar.gz; \
    cd cpython-3.11.4; \
    ./configure --prefix=/programs/python-3.11 --enable-optimizations; \
    make -j"${MAKE_JOBS}"; \
    make install; \
    cd /; \
    rm -rf /programs_build/python_build/cpython-3.11.4 /programs_build/python_build/v3.11.4.tar.gz

RUN set -eux; \
    cd /programs_build/python_build; \
    wget -q https://github.com/python/cpython/archive/v3.7.4.tar.gz; \
    tar -zxf v3.7.4.tar.gz; \
    cd cpython-3.7.4; \
    ./configure --prefix=/programs/python-3.7; \
    make -j"${MAKE_JOBS}"; \
    make install; \
    cd /; \
    rm -rf /programs_build/python_build/cpython-3.7.4 /programs_build/python_build/v3.7.4.tar.gz

# Create venv
RUN /programs/python-3.11/bin/python3 -m venv /venv \
 && /programs/python-3.7/bin/python3  -m venv /venv-3.7

# copiem requirements separat ca să cacheze pip
COPY --from=intermediate /saroj/WebServiceModules/TextExtractor/requirements.txt /tmp/tx-req.txt
COPY --from=intermediate /saroj/WebServiceModules/RNER/requirements.txt /tmp/rner-req.txt

RUN set -eux; \
    /venv/bin/pip3 install --upgrade pip; \
    /venv/bin/pip3 install --no-cache-dir -r /tmp/tx-req.txt; \
    /venv/bin/pip3 install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu; \
    /venv/bin/pip3 install --no-cache-dir rwpt scikit-learn; \
    /venv-3.7/bin/pip3 install --upgrade pip; \
    /venv-3.7/bin/pip3 install --no-cache-dir -r /tmp/rner-req.txt; \
    /venv-3.7/bin/pip3 install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu; \
    /venv-3.7/bin/pip3 install --no-cache-dir rwpt scikit-learn spacy flask; \
    rm -rf /root/.cache/pip

COPY --from=intermediate /saroj/WebServiceModules/ /modules/

# Setup Java
#RUN apt-get install -y default-jre
#RUN apt-get install -y openjdk-17-jre-headless
COPY openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb /
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ./openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb; \
    rm -rf /var/lib/apt/lists/* /openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb

COPY --from=intermediate /saroj/Rules/ /Rules/

# Setup site
COPY --from=intermediate /saroj/WebService/web/ /site/
RUN chown -R www-data:www-data /site/
COPY conf/apache2.conf /etc/apache2/
COPY conf/php.ini /usr/local/etc/php/
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_PID_FILE=/var/run/apache2.pid

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod a+rx /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/entrypoint.sh"]
