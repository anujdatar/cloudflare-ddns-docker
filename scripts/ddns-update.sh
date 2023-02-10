#!/bin/sh

. /common.sh
. /config.sh

# #####################################################################
# Step 1: Get current public IP

echo fetching record type $RECORD_TYPE

if [ "$RECORD_TYPE" == "A" ]; then
	CURRENT_IP=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com/)

	# check cloudflare's dns server if above method doesn't work
	if [ -z $CURRENT_IP ]; then
		echo using cloudflare whoami to find ip
    CURRENT_IP=$(dig txt ch +short whoami.cloudflare @1.1.1.1 | tr -d '"')
	fi
elif [ "$RECORD_TYPE" == "AAAA" ]; then
	CURRENT_IP=$(curl -s https://api6.ipify.org || curl -s https://ipv6.icanhazip.com/)

	# check cloudflare's dns server if above method doesn't work
	if [ -z $CURRENT_IP ]; then
		echo using cloudflare whoami to find ip
    CURRENT_IP=$(dig txt ch +short whoami.cloudflare @2606:4700:4700::1111 | tr -d '"')
	fi
fi

if [ -z $CURRENT_IP ]; then
    echo "No public IP found: check internet connection or network settings"
    exit 1
fi
echo "Current time: [$(date)]"
echo "Current Public IP: $CURRENT_IP"
# #####################################################################


# #####################################################################
# Step 2: Update ddns
# check registered ip against current public ip
OLD_IP=$(cat /old_record_ip)
echo "Stored IP address $OLD_IP"
if [ "$OLD_IP" == "$CURRENT_IP" ]; then
    echo "IP address is unchanged. Update not required."
else
	echo "Updating cloudflare record with current public ip"
	update=$(api_request -X PUT "$ENDPOINT/zones/$ZONE_ID/dns_records/$RECORD_ID" \
					--data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"proxied\":$PROXIED}")

	if [ $(echo $update | jq -r '.result.id') == "null" ]; then
		echo "Error updating Cloudflare DNS record $RECORD_NAME"
		echo "$update"
	else
		echo "DNS Record $RECORD_NAME IP updated to $CURRENT_IP"
		echo "$CURRENT_IP" > /old_record_ip
	fi
fi
# #####################################################################

print_breaker
