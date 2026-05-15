FROM ubuntu:24.04

ARG \
    WD=none \
    TZ=Europe/Moscow \
    LANG=ru_RU.UTF-8 \
    IMAGE_NAME=none \
    IMAGE_TAG=none

RUN \
    DEBIAN_FRONTEND=noninteractive apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        curl \
        iputils-ping \
        traceroute \
        dnsutils \
        iproute2 \
        python3 \
        p7zip-full \
        zip \
        unzip \
        nano \
        gettext-base \
        policykit-1 \
        zenity \
        evince \
        locales \
        supervisor \
        apache2 \
        fontconfig \
        redis-tools \
        python3-pip &&\
    pip install pydantic jinjanator redis --break-system-packages &&\
    DEBIAN_FRONTEND=noninteractive apt-get -y purge python3-pip &&\
    DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge &&\
    rm -rf /var/lib/apt/lists/*

ENV \
    TZ=${TZ} \
    LANG=${LANG}

RUN \
    localedef -i "${LANG%.*}" -c -f "${LANG#*.}" -A /usr/share/locale/locale.alias "$LANG"

RUN --mount=type=bind,source=${WD}/fonts.tgz,target=/fonts.tgz \
    mkdir -p /usr/local/share/fonts/mscorefonts &&\
    tar xzf /fonts.tgz -C /usr/local/share/fonts/mscorefonts &&\
    fc-cache -fv

LABEL \
    IMAGE_NAME=${IMAGE_NAME} \
    IMAGE_TAG=${IMAGE_TAG}
