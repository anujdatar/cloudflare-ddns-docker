#!/bin/sh

. /config.sh

# #####################################################################
# define the basic api request
api_request() {
  if [ "$METHOD" == "GLOBAL" ]; then
    curl -sSL \
    -H "Content-Type: application/json" \
    -H "X-Auth-Email: $EMAIL" \
    -H "X-Auth-Key: $API_KEY" \
    "$@"
  else
    curl -sSL \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    "$@"
  fi
}
# #####################################################################
# functions to get public ip
get_ip4() {
  CURRENT_IP=$(curl -s https://ipv4.icanhazip.com/ || curl -s https://api.ipify.org)
  if [ -z $CURRENT_IP ]; then
    dig_ip=$(dig txt ch +short whoami.cloudflare @1.1.1.1)
    if [ "$?" = 0 ]; then
      CURRENT_IP=$(echo $dig_ip | tr -d '"')
    else
      exit 1
    fi
  fi
  echo $CURRENT_IP
}

get_ip6() {
  CURRENT_IP=$(curl -s https://ipv6.icanhazip.com/ || curl -s https://api6.ipify.org)
  if [ -z $CURRENT_IP ]; then
    dig_ip=$(dig txt ch +short whoami.cloudflare @2606:4700:4700::1111)
    if [ "$?" = 0 ]; then
      CURRENT_IP=$(echo $dig_ip | tr -d '"')
    else
      exit 1
    fi
  fi
  echo $CURRENT_IP
}
# #####################################################################
# Step 1: Get current public IP
if [ "$RECORD_TYPE" == "A" ]; then
  CURRENT_IP=$(get_ip4)
elif [ "$RECORD_TYPE" == "AAAA" ]; then
  CURRENT_IP=$(get_ip6)
fi

if [ -z $CURRENT_IP ]; then
  echo "[$(date)]: Public IP not found, check internet connection"
  exit 1
fi
# #####################################################################
# Step 2: Check against old IP
OLD_IP=$(cat /old_record_ip)
if [ "$OLD_IP" == "$CURRENT_IP" ]; then
  echo "[$(date)]: IP unchanged, not updating. IP: $CURRENT_IP"
# #####################################################################
# Step 3: Update ddns
else
  update=$(api_request -X PUT "$ENDPOINT/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"proxied\":$PROXIED}")

  if [ $(echo $update | jq -r '.result.id') == "null" ]; then
    echo "[$(date)]: DDNS update failed...  Curr IP: $CURRENT_IP"
    echo "$update"
  else
    echo "[$(date)]: DDNS update successful...   IP: $CURRENT_IP"
    echo "$CURRENT_IP" > /old_record_ip
  fi
fi
# #####################################################################
