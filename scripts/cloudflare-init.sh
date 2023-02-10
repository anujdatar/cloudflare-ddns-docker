#!/bin/sh

echo "Container spun up at: [$(date)]"
. /common.sh

# #####################################################################
# Step 1: Check auth secrets and env variables
# 1. API key
print_breaker
echo "Performing basic container parameter check"
if [ -f "$API_KEY_FILE" ]; then
    API_KEY=$(cat "$API_KEY_FILE")
fi
if [ -z "$API_KEY" ]; then
    echo "Please enter valid API_KEY env variable or API_KEY_FILE secret"
    exit 1
fi
echo "API Key  ---  OK"

# 2. Zone
if [ -f "$ZONE_FILE" ]; then
    ZONE=$(cat "$ZONE_FILE")
fi
if [ -z "$ZONE" ]; then
    echo "Please enter valid ZONE env variable or ZONE_FILE secret"
    exit 1
fi
echo "Zone: $ZONE  ---  OK"

# 3. Subdomain
if [ -f "$SUBDOMAIN_FILE" ]; then
    SUBDOMAIN=$(cat "$SUBDOMAIN_FILE")
fi
if [ -z "$SUBDOMAIN" ]; then
    echo "No Subdomain/Record name provided"
    echo "Using DDNS updater on root zone $ZONE"
else
    echo "Subdomain: $SUBDOMAIN  ---  OK"
fi
# define record name as passed in by user
RECORD_NAME=$([ ! -z "$SUBDOMAIN" ] && echo "$SUBDOMAIN.$ZONE" || echo "$ZONE")
echo "Using DDNS updater on record: $RECORD_NAME"

# 4. Record Type
if [ "$RECORD_TYPE" == "A" ]; then
    echo "Record type to be updated: A (IPv4)"
elif [ "$RECORD_TYPE" == "AAAA" ]; then
    echo "Record type to be updated: AAAA (IPv6)"
else
    RECORD_TYPE="A"
    echo "Unknown record type, assuming A-record (IPv4)"
fi

# 5. Email - only needed if Global API key is used
if [ -f "$EMAIL_FILE" ]; then
    EMAIL=$(cat "$EMAIL_FILE")
fi
if [ ! -z "EMAIL" ]; then
    echo "Email: $EMAIL  ---  OK"
fi

# 6. ZoneID - optional, will be fetched later if not provided
if [ -f "$ZONE_ID_FILE" ]; then
    ZONE_ID=$(cat "$ZONE_ID_FILE")
    if [ ! -z "ZONE_ID" ]; then
        echo "Zone ID: $ZONE_ID  ---  OK"
    fi
fi

# 7. auth method check
if [ "$METHOD" == "GLOBAL" ] && [ -z "$EMAIL" ]; then
    echo "Please enter valid EMAIL env variable or EMAIL_FILE secret if using global api key"
    echo "Recommended method: Use a scoped API_KEY"
    echo "Generate a scoped (Zone/DDNS) key/token from:"
    echo "https://dash.cloudflare.com/profile/api-tokens"
    exit 1
fi
echo "Done - Everything seems to be in order"
# #####################################################################

# #####################################################################
# Step 2: Verify user email and token is valid
print_breaker
echo -n "Validating Cloudflare access tokens"
if [ "$METHOD" == "GLOBAL" ]; then
    echo "Using Global API token. It is recommended to use a scoped zone token for additional security"
    token_validity=$(api_request -o /dev/null -w "%{http_code}" "$ENDPOINT/user")
else
    token_validity=$(api_request -o /dev/null -w "%{http_code}" "$ENDPOINT/user/tokens/verify")
fi
if [ "$token_validity" != "200" ]; then
    echo "\nPlease check API_KEY and EMAIL. Please get your token from"
    echo "https://dash.cloudflare.com/profile/api-tokens"
    exit 1
fi
echo "  ---  OK"
# #####################################################################

# #####################################################################
# Step 3: Get Cloudflare ZoneID if not defined as env variable
print_breaker
echo "Verifying Cloudflare Zone ID"
if [ -z "$ZONE_ID" ]; then
    echo "Cloudflare Zone ID not passed as env variable, fetching from Cloudflare"
    ZONE_ID=$(api_request "$ENDPOINT/zones?name=$ZONE" | jq -r '.result[0].id')
fi
if [ "$ZONE_ID" == "null" ]; then
    echo "Zone: $ZONE not found in your Cloudflare account"
    exit 1
fi
echo "Zone ID: $ZONE_ID for $ZONE  ---  OK"
# #####################################################################

# #####################################################################
# Step 4: Get Cloudflare dns record details
print_breaker
echo -n "Fetching DNS Record details for $RECORD_NAME"
details=$(api_request "$ENDPOINT/zones/$ZONE_ID/dns_records?type=$RECORD_TYPE&name=$RECORD_NAME")
echo "  ---  Done"
# #####################################################################

# #####################################################################
# Step 5: Verify record details are valid
print_breaker
if [ $(echo $details | jq -r '.result_info.count') == 0 ]; then
    echo "$RECORD_NAME does not exist in your selected zone"
    echo "Check SUBDOMAIN env variable, or"
    echo "Create new record in cloudflare"
    exit 1
fi
echo "Record: $RECORD_NAME found on cloudflare  ---  OK"

# get record id
RECORD_ID=$(echo $details | jq -r '.result[0].id')
if [ "$RECORD_ID" == "null" ]; then
    echo "DNS Record ID for $RECORD_NAME invalid"
    exit 1
fi
echo "Record ID: $RECORD_ID for $RECORD_NAME  --- OK"

# get proxy status
if [ -z "$PROXIED" ]; then
    PROXIED=$(echo $details | jq -r '.result[0].proxied')
    echo "Since proxy status was not passed,"
    echo "Collecting proxied status from dns record"
    echo "Proxied: $PROXIED"
fi
# #####################################################################

# #####################################################################
# Step 6: Save relevant details in files
print_breaker
# get current IP for the record and store in container
RECORD_IP=$(echo $details | jq -r '.result[0].content')
echo "IP address on DNS record $RECORD_IP"
echo "$RECORD_IP" > /old_record_ip

# store zone_id, record_name, record_id in config
echo "ZONE_ID=\"$ZONE_ID\"" > /config.sh
echo "RECORD_NAME=\"$RECORD_NAME\"" >> /config.sh
echo "RECORD_TYPE=\"$RECORD_TYPE\"" >> /config.sh
echo "RECORD_ID=\"$RECORD_ID\"" >> /config.sh
echo "PROXIED=\"$PROXIED\"" >> /config.sh
# #####################################################################

echo "Cloudflare DDNS setup complete for $RECORD_NAME"
print_breaker
print_breaker
