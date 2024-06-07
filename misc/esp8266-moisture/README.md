# esp8266-moisture

MicroPython code for an ESP8266 to read moisture levels from a capacitive soil moisture sensor on a HTTP call, returns a single Prometheus metric.


## Deployment

`deploy.sh` will use webrepl_cli.py to connect and copy the files after replacing the secrets from envvar. See the
script for adding more secrets and adjust deploy target.
