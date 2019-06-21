#!/usr/bin/env bash

curl -s "https://api.cloudflare.com/client/v4/zones/6467f74f10e206068c311e586104ebe0/dns_records?per_page=100" \
    -H "Content-Type:application/json" \
    -H "X-Auth-Key:$CLOUDFLARE_TOKEN" \
    -H "X-Auth-Email:kradalby@kradalby.no" \
    | jq -r '.result | .[] | .name' \
    | ag "terra|leiden|tjoda|ntnu" \
    | sed "s/\.fap\.no//g" \
    | tr '\n' ' '
