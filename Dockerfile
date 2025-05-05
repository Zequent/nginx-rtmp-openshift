FROM buildpack-deps:jessie

# Setze die Archiv-Repositorys
RUN echo "deb http://archive.debian.org/debian jessie main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security jessie/updates main contrib non-free" >> /etc/apt/sources.list && \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

# Installiere Abhängigkeiten
RUN apt-get update && \
    apt-get install -y ca-certificates openssl libssl-dev wget && \
    rm -rf /var/lib/apt/lists/*
# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.11.3
ENV NGINX_RTMP_MODULE_VERSION 1.1.9
ENV NGINX_HOME=/home/nginx
ENV PATH "$PATH:/home/nginx"

# Install dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates openssl libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Download and extract Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and extract RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# We want to build Nginx into a home folder to better comply with
# openshift security
RUN useradd -U -m nginx && \
    mkdir -p ${NGINX_HOME}/etc && \
    mkdir -p ${NGINX_HOME}/var/lock && \
    mkdir -p ${NGINX_HOME}/var/log && \
    mkdir -p ${NGINX_HOME}/var/run
RUN cd /tmp/build/nginx/${NGINX_VERSION} && \
    ./configure \
        --sbin-path=${NGINX_HOME} \
        --conf-path=${NGINX_HOME}/etc/nginx.conf \
        --error-log-path=${NGINX_HOME}/var/log/error.log \
        --pid-path=${NGINX_HOME}/var/run/nginx.pid \
        --lock-path=${NGINX_HOME}/var/lock/nginx.lock \
        --http-log-path=${NGINX_HOME}/var/log/access.log \
        --http-client-body-temp-path=/tmp/nginx-client-body \
        --with-http_ssl_module \
        --with-threads \
        --with-ipv6 \
        --add-module=/tmp/build/nginx-rtmp-module/nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION} && \
    make -j $(getconf _NPROCESSORS_ONLN) && \
    make install && \
    rm -rf /tmp/build

# Set up config file
COPY nginx.conf ${NGINX_HOME}/etc/nginx.conf
RUN chgrp -R 0 ${NGINX_HOME} && \
    chmod -R g=u ${NGINX_HOME}
EXPOSE 1935
CMD ["/home/nginx/nginx", "-g", "daemon off;"]
#USER nginx
