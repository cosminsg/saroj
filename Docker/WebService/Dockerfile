FROM alpine as intermediate
LABEL stage=intermediate
RUN apk update && \
    apk add --update git
RUN git clone --depth 1 --branch master https://github.com/racai-ai/saroj.git /saroj

FROM php:7.4-apache
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update

# System stuff
RUN apt-get install -y tar zip unzip curl wget mc locales \
    gcc g++ make automake autoconf bison flex zlib1g zlib1g-dev \
    libffi-dev libssl-dev libbz2-dev libreadline-dev libgdbm-dev uuid uuid-dev \
    xz-utils libsqlite3-dev ncurses-dev
RUN echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen
RUN locale-gen en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# Build Python 3.11
RUN mkdir -p /programs /programs_build/python_build && \
    cd /programs_build/python_build && \
    wget -q https://github.com/python/cpython/archive/v3.11.4.tar.gz && \
    tar -zxf v3.11.4.tar.gz && \
    cd cpython-3.11.4 && \
    ./configure --prefix=/programs/python-3.11 --enable-optimizations && \
    make -j"$(nproc)" && \
    make install && \
    cd / && rm -rf /programs_build

# Creează venv pentru Python 3.11
RUN /programs/python-3.11/bin/python3 -m venv /venv

# Alias: /venv-3.7 va arăta către același venv
RUN ln -s /venv /venv-3.7

# Copiem modulele
COPY --from=intermediate /saroj/WebServiceModules/ /modules/
RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

# TextExtractor deps (în venv 3.11)
RUN /venv/bin/pip3 install -U pip setuptools wheel && \
    /venv/bin/pip3 install "numpy==1.26.4" && \
    /venv/bin/pip3 install -r /modules/TextExtractor/requirements.txt && \
    /venv/bin/pip3 install torch --index-url https://download.pytorch.org/whl/cpu && \
    /venv/bin/pip3 install rwpt scikit-learn

# RNER deps (în același venv, accesat prin aliasul /venv-3.7)
# --- toolchain de build pt pachete vechi (compat Py3.11) ---
RUN /venv/bin/pip3 install -U "pip<24.1" "setuptools<60" "wheel<0.40" "cython<3" "numpy<2"

# --- PyTorch compatibil cu cp311 ---
RUN /venv/bin/pip3 install torch==1.13.1+cpu -f https://download.pytorch.org/whl/cpu/torch_stable.html

# --- fairseq: bump la 0.10.2 (mai aproape de 0.9, API relativ stabil) ---
RUN /venv/bin/pip3 install --no-build-isolation "fairseq==0.12.2"

# --- instalează restul dependențelor RNER, dar ignoră pin-ul fairseq==0.9.0 din requirements ---
COPY --from=intermediate /saroj/WebServiceModules/RNER/requirements.txt /tmp/rner-req.txt
RUN awk '!/^fairseq==/ {print}' /tmp/rner-req.txt > /tmp/rner-req-no-fairseq.txt
RUN /venv/bin/pip3 install -r /tmp/rner-req-no-fairseq.txt

# Setup Java
COPY openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb /
RUN apt install -y /openjdk-17-jre-headless_17.0.10+7-1~deb11u1_amd64.deb

# Rules & site
COPY --from=intermediate /saroj/Rules/ /Rules/
COPY --from=intermediate /saroj/WebService/web/ /site/
RUN chown -R www-data:www-data /site/
COPY conf/apache2.conf /etc/apache2/
COPY conf/php.ini /usr/local/etc/php/
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_PID_FILE=/var/run/apache2.pid

# Entrypoint
COPY docker/entrypoint.sh /
RUN chmod a+rx /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/entrypoint.sh"]
