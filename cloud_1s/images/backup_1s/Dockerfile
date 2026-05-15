
ARG IMAGE_PARENT=none

FROM ${IMAGE_PARENT}

ARG \
    WD=none \
    IMAGE_PARENT=none \
    IMAGE_NAME=none \
    IMAGE_TAG=none

ENV \
    REDIS_IP=127.0.0.1 \
    CLUSTER_GW=127.0.0.1 \
    DIR_USER=1100 \
    DIR_GROUP=1100

RUN \
    mkdir -p /srv/1sdb1 /srv/1sadmin /srv/1smonthly /srv/1sdaily

COPY ${WD}/entrypoint.sh ${WD}/supervisord.conf ${WD}/cron.sh ${WD}/bak.list /

RUN \
    chmod 0755 /entrypoint.sh /cron.sh

ENTRYPOINT ["/entrypoint.sh"]

LABEL \
    IMAGE_PARENT=${IMAGE_PARENT} \
    IMAGE_NAME=${IMAGE_NAME} \
    IMAGE_TAG=${IMAGE_TAG}
