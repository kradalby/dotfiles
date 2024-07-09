import socket
import select
import time
import network
from machine import ADC, Pin


HIGH = 1
LOW = 0

MOISTURE_PIN = 0
MOISTURE_POWER_PIN = 13  # D7 https://www.bouvet.no/bouvet-deler/redd-plantene

moisture_power = Pin(MOISTURE_POWER_PIN, Pin.OUT)
moisture_sensor = ADC(MOISTURE_PIN)

moisture_power.value(LOW)


def read_with_power():
    moisture_power.value(HIGH)
    time.sleep_ms(300)
    val = moisture_sensor.read()
    moisture_power.value(LOW)
    return val


def read():
    count = 10
    raw = 0
    for _ in range(count):
        raw += moisture_sensor.read()

    raw /= count

    return raw

def req_handler(cs):
    try:
       req = cs.read()
       if req:
          print('Request:\n', req)
          cs.send('HTTP/1.1 200 OK\n')
          cs.send('Content-Type: text/plain\n')
          cs.send('Connection: close\n\n')
          cs.send(
              """# HELP sensor_moisture is the value read from pin 0, connected to moisture sensor
# TYPE sensor_moisture gauge
sensor_moisture {}""".format(
                  read_with_power()
              )
          )
       else:
          print('Client close connection')
    except Exception as e:
        print('Err:', e)
    cs.close()


def cln_handler(srv):
    cs, ca = srv.accept()
    print('Serving:', ca)
    cs.setblocking(False)
    cs.setsockopt(socket.SOL_SOCKET, 20, req_handler)


if __name__ == "__main__":
    port = 80
    address = socket.getaddrinfo("0.0.0.0", port)[0][-1]
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(address)
    srv.listen(5) # at most 5 clients
    srv.setblocking(False)
    srv.setsockopt(socket.SOL_SOCKET, 20, cln_handler)
