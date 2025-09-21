FROM alpine as intermediate
LABEL stage=intermediate
RUN apk add --no-cache git
RUN git clone --depth 1 --branch master https://github.com/racai-ai/saroj.git /saroj

# ——— Imagine finală
FROM php:7.4-apache
ARG DEBIAN_FRONTEND=noninteractive

# System stuff (quiet) + locale + rotatelogs
RUN apt-get update -qq && apt-get install -y -qq \
    tar zip unzip curl wget mc locales apache2-utils \
 && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
 && locale-gen \
 && rm -rf /var/lib/apt/lists/*

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Toolchain pt. Python build-from-source (ca în original, dar compactat și curățat)
RUN apt-get update -qq && apt-get install -y -qq \
    gcc g++ make automake autoconf bison flex zlib1g zlib1g-dev \
    libffi-dev libssl-dev libbz2-dev libreadline-dev libgdbm-dev uuid uuid-dev \
    xz-utils libsqlite3-dev ncurses-dev \
 && rm -rf /var/lib/apt/lists/*

# Build & install Python 3.11 (compact + cleanup pentru a salva spațiu)
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

# venv-ul principal (3.11)
RUN /programs/python-3.11/bin/python3 -m venv /venv

# Păstrăm compatibilitatea cu scripturile care caută /venv-3.7 fără a dubla pachetele
RUN ln -s /venv /venv-3.7

# Cod & module
COPY --from=intermediate /saroj/WebServiceModules/ /modules/
RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

# Dependențe Python (folosim --no-cache-dir ca să reducem spațiul, Torch cu CUDA 12.4)
# NOTĂ: roata PyTorch cu124 include runtime-ul necesar; driverele vin de pe host via --gpus all
RUN bash -lc 'source /venv/bin/activate && \
  pip3 install --upgrade pip && \
  [ -f /modules/TextExtractor/requirements.txt ] && pip3 install --no-cache-dir -r /modules/TextExtractor/requirements.txt || true && \
  [ -f /modules/RNER/requirements.txt ] && pip3 install --no-cache-dir -r /modules/RNER/requirements.txt || true && \
  pip3 install --no-cache-dir --index-url https://download.pytorch.org/whl/cu124 torch && \
  pip3 install --no-cache-dir rwpt scikit-learn spacy flask'

# Java
COPY openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb /
RUN apt-get update -qq && apt install -y -qq /openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb \
 && rm -rf /var/lib/apt/lists/* /openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb

# Rules & site
COPY --from=intermediate /saroj/Rules/ /Rules/
COPY --from=intermediate /saroj/WebService/web/ /site/
RUN chown -R www-data:www-data /site/

# Config Apache/PHP
COPY conf/apache2.conf /etc/apache2/
COPY conf/php.ini /usr/local/etc/php/
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_PID_FILE=/var/run/apache2.pid

# Entrypoint (și corecturi utile: folosim /usr/sbin/rotatelogs)
COPY docker/entrypoint.sh /
RUN chmod a+rx /entrypoint.sh \
 && sed -i 's#/usr/bin/rotatelogs#/usr/sbin/rotatelogs#g' /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/entrypoint.sh"]
