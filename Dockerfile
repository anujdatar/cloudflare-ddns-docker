FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/anujdatar/cloudflare-ddns-docker"
LABEL org.opencontainers.image.description="Cloudflare DynDNS Updater"
LABEL org.opencontainers.image.author="Anuj Datar <anuj.datar@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/anujdatar/cloudflare-ddns-docker/blob/main/README.md"
LABEL org.opencontainers.image.licenses=MIT

# default env variables
ENV FREQUENCY 5
ENV METHOD ZONE

# install dependencies
RUN apk update && apk add --no-cache curl bind-tools jq

# copy scripts over
COPY scripts /
RUN chmod 700 /entry.sh /container-setup.sh /common.sh /ddns-update.sh

CMD ["/entry.sh"]
