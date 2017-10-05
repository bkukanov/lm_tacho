from __future__ import print_function
import math
from math import degrees, radians, cos, sin, asin, sqrt, pi

o = {'lat': 53.810016, 'lon': -1.959652} # oxenhope
o = {'lat': 21.2765, 'lon': -157.8460} # waikiki

R = 6371 # earth radius in km
r = 1.0  # radius used in xy geometry

stepcount = 200
dtheta = 2*pi/stepcount # assuming curves have 2*pi periodicity

# ------------------------------------------------------------------------------
# haversine returns the distance between two points {latitude, longitude}
def haversine(p, q):

    dlat = radians(q['lat'] - p['lat'])
    dlon = radians(q['lon'] - p['lon'])
    lat1 = radians(p['lat'])
    lat2 = radians(q['lat'])

    a = sin(dlat/2)**2 + cos(lat1)*cos(lat2)*sin(dlon/2)**2
    c = 2*asin(sqrt(a))

    return c * R * 1000 # return value in metres

# ------------------------------------------------------------------------------
# geometry in the xy plane - here are some nice curves
def circle(t):
    x = r*cos(t)
    y = r*sin(t)
    return (x, y)

# lemniscate of bernoulli
def bernoulli(t):
    x = r*sqrt(2)*cos(t)/(sin(t)*sin(t)+1)
    y = r*sqrt(2)*cos(t)*sin(t)/(sin(t)*sin(t)+1)
    return (x, y)

# lemniscate of gerono
def gerono(t):
    x = r*cos(t)
    y = r*cos(t)*sin(t)
    return (x, y)

def geometry(t):
    x, y = circle(t)
    x, y = bernoulli(t)
    x, y = gerono(t)
    return (x, y)

# ------------------------------------------------------------------------------
# xy to geographical coordinates
def geographical(p):
    x, y = p
    # world coordinates R in km -> x,y in km, {lat, lon} in degrees
    lat = o['lat'] + degrees(y/R)
    lon = o['lon'] + degrees(x/(R*cos(radians(o['lat']))))
    return {'lat': lat, 'lon': lon}

# ------------------------------------------------------------------------------

# __main__

theta = 0
course = []
dist = 0

# calculate xy coordinates and map to geographical.
# R in km and geometry x,y in km {lat, lon} in degrees
p = geographical(geometry(theta))

for step in range(stepcount):

    theta += dtheta

    q = geographical(geometry(theta))

    dist += haversine(p, q)

    # record p once we know the distance to q
    course.append([p['lat'], p['lon'], dist])
    # p can be plotted at https://www.darrinward.com/lat-long/
    print("{},{}".format(p['lat'], p['lon']))
    p = q

print(dist)
