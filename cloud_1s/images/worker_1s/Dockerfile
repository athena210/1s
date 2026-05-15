
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
    BASE_NAME=none \
    TIME_LOOP=10 \
    NO_USERS_SEEN_TO_RESTART=180 \
    HASP_SERVER=127.0.0.1 \
    REDIS_IP=127.0.0.1 \
    CLUSTER_GW=127.0.0.1 \
    DIR_USER=1100 \
    DIR_GROUP=1100

RUN --mount=type=bind,source=${FILE_DISTR},target=/1s.zip \
    mkdir -p /1s /db /var/1spub/db /var/log/1s &&\
    ln -snf /dev/stderr /var/log/apache2/error.log &&\
    ln -sf /dev/null /var/log/apache2/access.log &&\
    ln -sf /dev/null /var/log/apache2/other_vhosts_access.log &&\
    echo "{}" > /1sstat &&\
    unzip /1s.zip -d /1s &&\
    /1s/setup-full-${VERSION_1S}-x86_64.run --mode unattended --enable-components server,ws,liberica_jre,ru &&\
    /1s/all-clients-distr-${VERSION_1S}-x86_64.run --mode unattended &&\
    rm -rf /1s

COPY ${WD}/status.conf ${WD}/mpm_event.conf /etc/apache2/mods-available/

COPY ${WD}/servername.conf /etc/apache2/conf-available/

COPY ${WD}/logcfg.xml /opt/1cv8/conf/

COPY ${WD}/wconf/ /wconf

COPY ${WD}/entrypoint.sh ${WD}/supervisord.conf ${WD}/shepard.py /

RUN \
    chmod 0755 /entrypoint.sh /shepard.py && \
    ln -snf ../conf-available/servername.conf /etc/apache2/conf-enabled/servername.conf

ENTRYPOINT ["/entrypoint.sh"]

HEALTHCHECK --timeout=5s --retries=2 --start-period=5s \
    CMD curl -sf http://localhost/${BASE_NAME}/ || exit 1

LABEL \
    VERSION_1S=${VERSION_1S} \
    IMAGE_PARENT=${IMAGE_PARENT} \
    IMAGE_NAME=${IMAGE_NAME} \
    IMAGE_TAG=${IMAGE_TAG}
