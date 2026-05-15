
ARG IMAGE_PARENT=none

FROM ${IMAGE_PARENT}

ARG \
    WD=none \
    IMAGE_PARENT=none \
    IMAGE_NAME=none \
    IMAGE_TAG=none


ENV \
    DIR_USER=1100 \
    DIR_GROUP=1100

RUN \
    DEBIAN_FRONTEND=noninteractive apt-get update &&\
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        sudo \
        samba &&\
    rm -rf /var/lib/apt/lists/*

RUN \
    mkdir -p /srv/1sdb1 /srv/1sadmin /srv/1sdaily /srv/1smonthly

COPY ${WD}/smb.conf /etc/samba/smb.conf

COPY ${WD}/entrypoint.sh ${WD}/supervisord.conf /

RUN \
    chmod 0755 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

LABEL \
    IMAGE_PARENT=${IMAGE_PARENT} \
    IMAGE_NAME=${IMAGE_NAME} \
    IMAGE_TAG=${IMAGE_TAG}
