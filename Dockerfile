FROM alpine:latest

# default env variables
ENV FREQUENCY 5
ENV METHOD ZONE

# install dependencies
RUN apk update && apk add --no-cache curl jq

# copy scripts over
COPY scripts /
RUN chmod 700 /cloudflare-init.sh /entry.sh /common.sh /ddns-update.sh

CMD ["/entry.sh"]
