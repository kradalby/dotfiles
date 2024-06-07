#!/bin/bash
echo "Password:"
read -rs password
echo

OUT="$(mktemp -d /tmp/output.XXXXXXXXXX)" || {
	echo "Failed to create temp file"
	exit 1
}
cp boot.py main.py "$OUT/"
find "$OUT" -type f -exec sed -i "s/@WIFI_SSID@/$WIFI_IOT_SSID/g" {} \;
find "$OUT" -type f -exec sed -i "s/@WIFI_PASSPHRASE@/$WIFI_IOT_PASSPHRASE/g" {} \;

webrepl_cli -p "$password" "$OUT"/boot.py living-room-window-moisture.ldn:8266:/boot.py
# The webrepl is a bit fragile and fails if called too quickly in succession,
# so give it a couple of seconds before copying the next file.
sleep 3
webrepl_cli -p "$password" "$OUT"/main.py living-room-window-moisture.ldn:8266:/main.py

rm -rf "$OUT"
