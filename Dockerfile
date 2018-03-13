FROM buildpack-deps:jessie

# Versions of Nginx and nginx-rtmp-module to use
ENV NGINX_VERSION nginx-1.11.3
ENV NGINX_RTMP_MODULE_VERSION 1.1.9
ENV NGINX_HOME=/home/nginx
ENV PATH "$PATH:/home/nginx"

# Install dependencies
RUN apt-get update && \
    apt-get install -y ca-certificates openssl libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Download and decompress Nginx
RUN mkdir -p /tmp/build/nginx && \
    cd /tmp/build/nginx && \
    wget -O ${NGINX_VERSION}.tar.gz https://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxf ${NGINX_VERSION}.tar.gz

# Download and decompress RTMP module
RUN mkdir -p /tmp/build/nginx-rtmp-module && \
    cd /tmp/build/nginx-rtmp-module && \
    wget -O nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz https://github.com/arut/nginx-rtmp-module/archive/v${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    tar -zxf nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}.tar.gz && \
    cd nginx-rtmp-module-${NGINX_RTMP_MODULE_VERSION}

# Build and install Nginx
# The default puts everything under /usr/local/nginx, so it's needed to change
# it explicitly. Not just for order but to have it in the PATH
RUN useradd -U -m nginx && mkdir -p ${NGINX_HOME}/etc && mkdir -p ${NGINX_HOME}/var/lock && mkdir -p ${NGINX_HOME}/var/log && mkdir -p ${NGINX_HOME}/var/run  && touch ${NGINX_HOME}/var/log/error.log && touch ${NGINX_HOME}/var/log/access.log && chown -R nginx:nginx ${NGINX_HOME}
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

# Forward logs to Docker
RUN ln -sf /dev/stdout ${NGINX_HOME}/var/log/access.log && \
    ln -sf /dev/stderr ${NGINX_HOME}/var/log/error.log

# Set up config file
COPY nginx.conf ${NGINX_HOME}/etc/nginx.conf
RUN chown -R nginx:nginx ${NGINX_HOME}
EXPOSE 1935
CMD ["/home/nginx/nginx", "-g", "daemon off;"]
#USER nginx
