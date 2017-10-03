import serial
from datetime import datetime

tty = serial.Serial("/dev/ttyUSB1", timeout=0)

while 1:
    v = tty.readline()[:-2]               # strip off last two bytes \r\n
    if len(v) == 4:
        print(datetime.now(), int(v[3])*256*256*256 + int(v[2]*256*256) + int(v[1]*256) + int(v[0]));
