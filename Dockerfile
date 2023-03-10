FROM docwilco/lancache-ubuntu-nginx:latest
LABEL version=3
LABEL description="Single caching container for caching game content at LAN parties, using Varnish."
LABEL maintainer="DocWilco <github@drwil.co>"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y jq git libgetdns10 libgetdns-dev automake libtool docutils-common autoconf libpcre2-dev pkg-config
RUN curl -s https://packagecloud.io/install/repositories/varnishcache/varnish72/script.deb.sh | bash
RUN apt-get install -y varnish varnish-dev

ENV GENERICCACHE_VERSION=2 \
    CACHE_MODE=monolithic \
    WEBUSER=www-data \
    CACHE_INDEX_SIZE=500m \
    CACHE_DISK_SIZE=1000g \
    CACHE_MAX_AGE=3560d \
    CACHE_SLICE_SIZE=1m \
    UPSTREAM_DNS="8.8.8.8 8.8.4.4" \
    BEAT_TIME=1h \
    LOGFILE_RETENTION=3560 \
    CACHE_DOMAINS_REPO="https://github.com/uklans/cache-domains.git" \
    CACHE_DOMAINS_BRANCH=master \
    NGINX_WORKER_PROCESSES=auto

RUN apt-get install -y dnsutils vim

ADD https://api.github.com/repos/nigoroll/libvmod-dynamic/git/ref/heads/master /tmp/libvmod-dynamic-version.json
RUN cd /tmp &&\
    git clone --branch 7.2 https://github.com/nigoroll/libvmod-dynamic.git && \
    cd libvmod-dynamic && \
    ./autogen.sh && \
    ./configure && \
    make && \
    make install
RUN rm /tmp/libvmod-dynamic-version.json

ADD https://code.uplex.de/api/v4/projects/8/repository/branches/master /tmp/libvmod-re-version.json
RUN cd /tmp && \
    git clone https://code.uplex.de/uplex-varnish/libvmod-re.git && \
    cd libvmod-re && \
    ./autogen.sh && \
    ./configure && \
    make && \
#    make check && \
    make install
RUN rm /tmp/libvmod-re-version.json

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
# Adding this URL will force a rebuild of the cached image when the main branch is updated
ADD https://api.github.com/repos/docwilco/cachedomains2vcl/git/ref/heads/main /tmp/cachedomains2vcl-version.json
RUN . "$HOME/.cargo/env" && \
    CARGO_NET_GIT_FETCH_WITH_CLI=true cargo install --git https://github.com/docwilco/cachedomains2vcl.git && \
    mv "$HOME/.cargo/bin/cachedomains2vcl" /usr/local/bin/cachedomains2vcl
RUN rm /tmp/cachedomains2vcl-version.json

COPY overlay/ /

RUN rm -f /etc/nginx/sites-enabled/* /etc/nginx/stream-enabled/* && \
    rm /etc/nginx/conf.d/gzip.conf && \
    id -u ${WEBUSER} &> /dev/null || adduser --system --home /var/www/ --no-create-home --shell /bin/false --group --disabled-login ${WEBUSER} && \
    chmod 755 /scripts/*   && \
    mkdir -m 755 -p /data/cache  && \
    mkdir -m 755 -p /data/info  && \
    mkdir -m 755 -p /data/logs  && \
    chown -R ${WEBUSER}:${WEBUSER} /data/ && \
    ln -s /etc/nginx/stream-available/10_sni.conf /etc/nginx/stream-enabled/10_sni.conf

#VOLUME ["/data/logs", "/data/cache", "/data/cachedomains", "/var/www"]
#
#EXPOSE 80 443
#WORKDIR /scripts
#