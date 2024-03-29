FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/anujdatar/cloudflare-ddns-docker"
LABEL org.opencontainers.image.description="Cloudflare DDNS Updater"
LABEL org.opencontainers.image.author="Anuj Datar <anuj.datar@gmail.com>"
LABEL org.opencontainers.image.url="https://github.com/anujdatar/cloudflare-ddns-docker/blob/main/README.md"
LABEL org.opencontainers.image.licenses=MIT

# default env variables
ENV FREQUENCY 5
ENV RECORD_TYPE A
ENV METHOD ZONE
ENV ENDPOINT "https://api.cloudflare.com/client/v4"

# install dependencies
RUN apk update && apk add --no-cache tzdata curl bind-tools jq

# copy scripts over
COPY scripts /
RUN chmod 700 /entry.sh /container-setup.sh /ddns-update.sh

CMD ["/entry.sh"]
