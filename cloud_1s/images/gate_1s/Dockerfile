FROM alpine:3.23

ARG \
    WD=none \
    IMAGE_NAME=none \
    IMAGE_TAG=none

ENV \
    USE_DNS=127.0.0.1 \
    CLUSTER_NET=127.0.0.0/8

RUN \
    apk --no-cache add \
        ca-certificates \
        tzdata \
        curl \
        supervisor \
        dnsmasq \
        iptables

RUN \
    set -ex; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
        armhf) arch='armv6' ;; \
        armv7) arch='armv7' ;; \
        aarch64) arch='arm64' ;; \
        x86_64) arch='amd64' ;; \
        riscv64) arch='riscv64' ;; \
        s390x) arch='s390x' ;; \
        ppc64le) arch='ppc64le' ;; \
        *) echo >&2 "error: unsupported architecture: $apkArch"; exit 1 ;; \
    esac; \
    wget --quiet -O /tmp/traefik.tar.gz "https://github.com/traefik/traefik/releases/download/v3.6.12/traefik_v3.6.12_linux_$arch.tar.gz"; \
    tar xzvf /tmp/traefik.tar.gz -C /usr/local/bin traefik; \
    rm -f /tmp/traefik.tar.gz; \
    chmod +x /usr/local/bin/traefik

COPY ${WD}/entrypoint.sh ${WD}/supervisord.conf ${WD}/traefik.yml /

RUN \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

LABEL \
    IMAGE_NAME=${IMAGE_NAME} \
    IMAGE_TAG=${IMAGE_TAG}
