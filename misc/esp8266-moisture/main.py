import socket
import time

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


addr = socket.getaddrinfo("0.0.0.0", 80)[0][-1]

s = socket.socket()
s.bind(addr)
s.listen(5)

print("listening on", addr)

while True:
    cl, addr = s.accept()
    print("client connected from", addr)
    cl_file = cl.makefile("rwb", 0)
    while True:
        line = cl_file.readline()
        if not line or line == b"\r\n":
            break
    cl.send("HTTP/1.0 200 OK\r\nContent-type: text/plain\r\n\r\n")
    cl.send(
        """# HELP sensor_moisture is the value read from pin 0, connected to moisture sensor
# TYPE sensor_moisture gauge
sensor_moisture {}""".format(
            read_with_power()
        )
    )
    cl.close()
