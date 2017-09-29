import serial
import re

tty = serial.Serial("/dev/ttyUSB1")

while 1:
    # readline returns bytes, convert to string and extract decimal digits
    # this gives a list, but we only want element [0] as an integer
    v = int(re.findall(r'\d+', str(tty.readline()))[0])
    print(v)
