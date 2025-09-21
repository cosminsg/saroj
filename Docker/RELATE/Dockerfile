# ---- Stage 0: adu codul SAROJ
FROM alpine AS intermediate
LABEL stage=intermediate
RUN apk add --no-cache git
RUN git clone --depth 1 --branch master https://github.com/racai-ai/saroj.git /saroj

# ---- Stage 1: Python 3.11 prebuilt (evităm compilarea din surse)
FROM python:3.11-slim AS py311

# ---- Stage 2: imagine finală
FROM php:7.4-apache
ARG DEBIAN_FRONTEND=noninteractive

# Utils + locale + rotatelogs
RUN apt-get update -qq && apt-get install -y -qq \
    tar zip unzip curl wget mc locales apache2-utils \
 && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
 && locale-gen \
 && rm -rf /var/lib/apt/lists/*
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Adu Pythonul precompilat
COPY --from=py311 /usr/local/ /usr/local/
ENV PATH=/usr/local/bin:$PATH

# Un singur venv (Py3.11) pt toate modulele (inclusiv RNER)
RUN python3 -m venv /venv
# compat: dacă scripturi vechi pomenesc /venv-3.7, trimite-le spre /venv
RUN ln -s /venv /venv-3.7

# Cod & modules
COPY --from=intermediate /saroj/WebServiceModules/ /modules/
RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

# Dependențe Python (pin-uri pt compat fairseq/spaCy, Torch cu CUDA 12.4)
# NOTĂ: Torch cu124 include runtime-ul CUDA necesar; driverele vin din host via --gpus all
RUN bash -lc 'set -e; source /venv/bin/activate && \
  pip install --upgrade pip && \
  pip install --no-cache-dir "numpy==1.26.4" && \
  pip install --no-cache-dir "thinc==8.2.5" "spacy==3.7.5" && \
  [ -f /modules/TextExtractor/requirements.txt ] && pip install --no-cache-dir -r /modules/TextExtractor/requirements.txt || true && \
  [ -f /modules/RNER/requirements.txt ] && pip install --no-cache-dir -r /modules/RNER/requirements.txt || true && \
  pip install --no-cache-dir "fairseq==0.12.2" && \
  pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu124 torch && \
  pip install --no-cache-dir rwpt scikit-learn flask'

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

# Entrypoint (forțăm /usr/bin/rotatelogs & /venv)
COPY docker/entrypoint.sh /
RUN chmod a+rx /entrypoint.sh \
 && sed -ri 's#/usr/sbin/rotatelogs#/usr/bin/rotatelogs#g; s#\brotatelogs\b#/usr/bin/rotatelogs#g; s#/venv-3.7#/venv#g' /entrypoint.sh \
 && grep -q "/usr/bin/rotatelogs" /entrypoint.sh || true

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/entrypoint.sh"]
