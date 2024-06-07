#!/bin/bash
echo "Password:"
read -rs password
echo

# TODO(kradalby): Replace secrets before deploy:
# Copy to mktemp
# sed s/$WIFI_IOT_SSID/<WIFI_SSID>/g
# sed s/$WIFI_IOT_PASSPHRASE/<WIFI_PASSPHRASE>/g
# webrepl copy
# cleanup

# webrepl_cli -p "$password" boot.py living-room-window-moisture.ldn:8266:/boot.py
# The webrepl is a bit fragile and fails if called too quickly in succession,
# so give it a couple of seconds before copying the next file.
# sleep 3
# webrepl_cli -p "$password" main.py living-room-window-moisture.ldn:8266:/main.py
