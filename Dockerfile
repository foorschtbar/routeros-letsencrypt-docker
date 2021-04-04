# Dockerfile: https://hub.docker.com/r/goacme/lego/
FROM goacme/lego:latest

RUN apk update \
    && apk add --no-cache openssh-client

COPY crontab /var/spool/cron/crontabs/root
RUN chown -R root:root /var/spool/cron/crontabs/root && chmod -R 640 /var/spool/cron/crontabs/root

COPY app/*.sh /app/
RUN chown -R root:root /app; \
    chmod -R 550 /app; \
    chmod +x /app/*.sh; \
    dos2unix /app/*.sh; \
    mkdir -p /letsencrypt

# This is the only signal from the docker host that appears to stop crond
STOPSIGNAL SIGKILL

ENTRYPOINT "/app/cron.sh"