# define the basic api request

ENDPOINT="https://api.cloudflare.com/client/v4"

if [ -f "$API_KEY_FILE" ]; then
    API_KEY=$(cat "$API_KEY_FILE")
fi

if [ -f "$EMAIL_FILE" ]; then
    EMAIL=$(cat "$EMAIL_FILE")
fi


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

print_breaker() {
    echo "-----------------------------------------------"
}