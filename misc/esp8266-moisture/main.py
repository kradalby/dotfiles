import socket

import machine


def read():
    p = machine.ADC(0)

    count = 10
    raw = 0
    for _ in range(count):
        raw += p.read()

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
            read()
        )
    )
    cl.close()
