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

## Using IPv6
Docker by default only has IPv4 enabled. So containers can only access the web through IPv4. IPv6 traffic is not available by default. There are a few ways you can enable this, these are the quickest I found. I will link official docs where possible.

First you will have to allow IPv6 internet access to the docker subnet on your Host machine. Assuming the private Docker subnet we assign in the steps below is `fd00::/64`. You can use a different subnet if you wish. Or you may need to use a different subnet if you have multiple docker networks with IPv6 enabled.
```bash
ip6tables -t nat -A POSTROUTING -s fd00::/64 ! -j MASQUERADE
```
This setting is not persistent, and will not survive a reboot. To make it persistent

```bash
# install iptables-persistent and netfilter-persistent
sudo apt-get install iptables-persistent netfilter-persistent

# save you rules
sudo iptables-save > /etc/iptables/rules.v4
sudo ip6tables-save > /etc/iptables/rules.v6

# restart services
sudo systemctl restart netfilter-persistent

# if you need to restore backed-up rules
sudo iptables-restore < /etc/iptables/rules.v4
sudo ip6tables-restore < /etc/iptables/rules.v6
```
For more information on persistent rules or iptables on RPM based systems, refer to
[1](https://askubuntu.com/questions/1052919/iptables-reload-restart-on-ubuntu/1072948#1072948)
and [2](https://linuxconfig.org/how-to-make-iptables-rules-persistent-after-reboot-on-linux)

For more on IPv6 and docker you can check out this [medium](https://medium.com/@skleeschulte/how-to-enable-ipv6-for-docker-containers-on-ubuntu-18-04-c68394a219a2) article. I do not expose individual docker containers to internet via IPv6 directly, but the article goes over ways to do this. If you need it.

### 1. Enable IPv6 on the default bridge network
Source: [Docker Docs - IPv6](https://docs.docker.com/config/daemon/ipv6/)
1. Edit `etc/docker/daemon.json` and add the following
   ```json
    {
      "ipv6": true,
      "fixed-cidr-v6": "fd00::/64"
    }
   ```
2. Reload the docker config file
   ```sh
   $ systemctl reload docker
   # or restart the docker service
   $ systemctl restart docker
   ```
3. You can now start any container connected to the default bridge. You should have IPv6 access. To connect a docker-compose container to default bridge, add `network_mode: bridge` option to the service.

### 2. Create a new persistent network with IPv6 access
In case you want to keep your networks separate.
```bash
docker network create --subnet=172.16.2.0/24 --gateway=172.16.2.1 --ipv6 --subnet=fd00::/64 ipv6bridge
```
You can now connect your container to this network using `--network ipv6bridge`. Or in your `docker-compose.yml` file using
```yaml
services:
  your-service-name:
    image: xyz
    other-options: options
    networks:
      - my-net

networks:
  my-net:
    external:
      name: ipv6bridge
```

or
```yaml
services:
  your-service-name:
    image: xyz
    other-options: options

networks:
  default:
    external:
      name: ipv6bridge
```

### 3. Define the network in your `docker-compose` file
This will be a disposable network, and will be removed when you stop your application. This example changes the default network of all the services in the application. You can create a named network and assign it to services individually as well.

Source: [Docker Compose Networking](https://docs.docker.com/compose/networking/)
```yaml
services:
  your-service-name:
    image: xyz
    other-options: options

networks:
  default:
    driver: bridge
    enable_ipv6: true
    ipam:
      driver: default
      config:
        - subnet: fd00::/64
```
---
## Creating a Scoped Token on Cloudflare
To create a scoped token with only DNS privileges, go to https://dash.cloudflare.com/profile/api-tokens and create a CUSTOM TOKEN with the following permissions
1. Zone - Zone Settings - Read
2. Zone - Zone - Read
3. Zone - DNS - Edit

You may choose to include all zones on one specific zone based on your preferences.
