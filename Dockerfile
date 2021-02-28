FROM debian:bullseye AS builder

RUN set -x \
&& apt-get update \
&& apt-get install -y make cmake g++ golang

ADD . /
RUN set -x \
&& cd /build/boringssl \
&& mkdir build \
&& cd build && cmake ../ && make \
&& cd /build/nginx-quic \
&& ./auto/configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-1.19.6/debian/debuild-base/nginx-1.19.6=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' --with-pcre=../pcre --with-pcre-jit --with-zlib=../zlib --with-http_v3_module --with-cc-opt=-I../boringssl/include --with-ld-opt='-L../boringssl/build/ssl -L../boringssl/build/crypto' \
&& make -j$(nproc)

WORKDIR /rootfs
RUN mkdir -p \
'etc/nginx' \
'usr/sbin' \
'var/run' \
'var/log/nginx' \
'var/cache/nginx/client_temp' \
&& ln -sf /dev/stdout var/log/nginx/access.log \
&& ln -sf /dev/stderr var/log/nginx/error.log \
&& cp -R /build/nginx-quic*/docs/html 'etc/nginx' \
&& cp /build/nginx-quic*/objs/nginx 'usr/sbin/nginx' \
&& cp /build/nginx-quic*/conf/* 'etc/nginx'

FROM debian:bullseye-slim

RUN set -x \
&& addgroup --system --gid 101 nginx \
&& adduser --system --disabled-login --ingroup nginx --no-create-home --home / --gecos "nginx user" --shell /bin/false --uid 101 nginx \
&& apt-get update \
&& apt-get install --no-install-recommends --no-install-suggests -y ca-certificates \
&& apt-get clean

COPY --from=builder /rootfs /

EXPOSE 80
STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
