import math

# plot here: https://www.darrinward.com/lat-long/
# it requires a comma and no spaces...
# worldpath.py | sed -e 's/ /,/'

R = 6371 # earth radius in km
r = 1.0  # geometry radius

olon = -1.959652
olat = 53.810016

print(olat, olon)
stepcount = 200

dtheta = 2*math.pi/stepcount # all these curves have 2*pi periodicity

theta = 0

for step in range(stepcount):
    # geometry - circle
    x = r*math.cos(theta)
    y = r*math.sin(theta)
    # lemniscate of bernoulli
    x = r*math.sqrt(2)*math.cos(theta)                /(math.sin(theta)*math.sin(theta)+1)
    y = r*math.sqrt(2)*math.cos(theta)*math.sin(theta)/(math.sin(theta)*math.sin(theta)+1)
    # lemniscate of gerono
    x = r*math.cos(theta)
    y = r*math.cos(theta)*math.sin(theta)

    # world coordinates R in km -> x,y in km, {lat, lon} in degrees
    plat = olat + 180*y/(math.pi*R)
    plon = olon + 180*x/(math.pi*R*math.cos(math.radians(olat)))

    print(plat,plon)

    theta += dtheta
