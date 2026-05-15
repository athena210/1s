
ARG IMAGE_PARENT=none

FROM ${IMAGE_PARENT}

ARG \
    WD=none \
    VERSION_1S=none \
    IMAGE_PARENT=none \
    IMAGE_TAG=none \
    IMAGE_NAME=none \
    FILE_DISTR=none

ENV \
    VERSION_1S=${VERSION_1S} \
    HASP_SERVER=127.0.0.1 \
    REDIS_IP=127.0.0.1 \
    DIR_USER=1100 \
    DIR_GROUP=1100

RUN \
    DEBIAN_FRONTEND=noninteractive apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        tigervnc-standalone-server \
        lxqt-core \
        dbus-x11 \
        libwebkit2gtk-4.1-0 \
        sudo \
        mc &&\
    rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=${FILE_DISTR},target=/1s.zip \
    mkdir -p /1s &&\
    unzip /1s.zip -d /1s &&\
    /1s/setup-full-${VERSION_1S}-x86_64.run --mode unattended --enable-components additional_admin_functions,client_full,client_thin,desktop_icons,integrity_monitoring,liberica_jre,ru &&\
    rm -rf /1s

RUN \
    mkdir -p /srv/1sdb1 /srv/1sadmin

COPY ${WD}/wconf/ /wconf

COPY ${WD}/entrypoint.sh ${WD}/supervisord.conf ${WD}/keyboard.desktop /

RUN \
    chmod 0755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

LABEL \
    VERSION_1S=${VERSION_1S} \
    IMAGE_PARENT=${IMAGE_PARENT} \
    IMAGE_NAME=${IMAGE_NAME} \
    IMAGE_TAG=${IMAGE_TAG}
