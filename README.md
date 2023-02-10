# Cloudflare DynDNS Updater in a docker

Update IP on Cloudflare periodically. Works with docker secrets. Built for `amd64`, `arm64` and `armv7`, but only tested on `amd64`, and `arm64`.

Now using alpine:latest image for a small footprint. I know alpine:3.13 had an issue with `armv7`. Have not tested latest image on `armv7`. If you have issues, let me know. Will revert to alpine:3.12.

Now supports IPv6 or AAAA record updates too, but this needs additional settings. Please read [section](#using-ipv6) below.
---

## Parameters / Environment Variables
| # | Parameter | Default | Notes | Description |
| - | --------- | ------- | ----- | ----------- |
| 1 | API_KEY | - | REQUIRED | Your Cloudflare API Key/Token. Global or Zone (scoped) |
| 2 | EMAIL | - | OPTIONAL | Registered email on Cloudflare, REQUIRED if using METHOD=GLOBAL |
| 3 | RECORD_TYPE | A | OPTIONAL | Record types supported A (IPv4) and AAAA (IPv6) |
| 4 | ZONE | - | REQUIRED | The root DNS zone/domain registered on Cloudflare |
| 5 | SUBDOMAIN | - | OPTIONAL | The DNS subdomain/A-record you want to update. Root Zone is used if nothing is provided |
| 6 | ZONE_ID | - | OPTIONAL | The Zone ID for domain registered on Cloudflare. Will be fetched from Cloudflare if nothing is provided |
| 7 | FREQUENCY | 5 | OPTIONAL | Frequency of IP updates on Cloudflare (default - every 5 mins) |
| 8 | METHOD | ZONE | OPTIONAL | Authentication method - Zone API Token or Global API Token (ZONE or GLOBAL). Global method also required EMAIL |
| 9 | PROXIED | - | OPTIONAL | true/false boolean, whether record should use Cloudflare CDN. Uses Cloudflare preset for record if nothing is explicitly provided |

#### Multiple subdomains
In order to update multiple DNS records with your dynamic IP, please create `CNAME` records and point them to the `A` or `AAAA` record used in this container.

---

## USAGE

### Docker cli
**Recommended** method is using a scoped API token (zone). Limits the privileges given to the container.
```bash
docker run \
    -e API_KEY="<your-scoped-api-token>" \
    -e ZONE="<your-dns-zone>"  \
    -e SUBDOMAIN="<subdomain-a-record>" \
    -e RECORD_TYPE=A \
    --name cloudflare-ddns \
    anujdatar/cloudflare-ddns

```

Using a global API token
```bash
docker run \
    -e METHOD=GLOBAL \
    -e API_KEY="<your-global-api-token>" \
    -e EMAIL="email@example.com" \
    -e ZONE="<your-dns-zone>"  \
    -e SUBDOMAIN="<subdomain-a-record>" \
    --name cloudflare-ddns \
    anujdatar/cloudflare-ddns

```

### docker-compose

```yaml
version: "3"
services:
  cloudflare-ddns:
    image: anujdatar/cloudflare-ddns
    container_name: cloudflare-ddns
    restart: unless-stopped
    environment:
      - API_KEY="<your-scoped-api-token>"
      - ZONE="<your-dns-zone>"
      - SUBDOMAIN="<subdomain-a-record>"
      - FREQUENCY=1  # OPTIONAL, default is 5

```

### using docker-compose and docker secrets
In case you plan to commit your docker-compose files to repos and wish to keep tokens/domains secure
```yaml
version: "3"
services:
  cloudflare-ddns:
    image: anujdatar/cloudflare-ddns
    container_name: cloudflare-ddns
    restart: unless-stopped
    environment:
      - METHOD=GLOBAL
      - API_KEY_FILE=/run/secrets/api_key
      - EMAIL=/run/secrets/email
      - ZONE=/run/secrets/zone
    secrets:
      - api_key
      - email
      - zone

secrets:
  api__key:
    external: true
  email:
    file: ./email.txt
  zone:
  	file: ./zone.txt

```

External secrets can be Docker Secrets created using the `docker secret create` command
```bash
echo <your-scoped-api-token> | docker secret create api_key -

```

Your secret files should just be plain text strings containing zone/subdomain/email/token etc.

#### email.txt
```txt
email@example.com
```
#### zone.txt
```txt
example.com
```
---

## Creating a Scoped Token on Cloudflare
To create a scoped token with only DNS privileges, go to https://dash.cloudflare.com/profile/api-tokens and create a CUSTOM TOKEN with the following permissions
1. Zone - Zone Settings - Read
2. Zone - Zone - Read
3. Zone - DNS - Edit

You may choose to include all zones on one specific zone based on your preferences.

## Todo:
Add 1pv6 support
