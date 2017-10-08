#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ai ts=4 sts=4 et sw=4 nu

'''
Gauge
=====

The :class:`Gauge` widget is a widget for displaying gauge.

.. note::

Source svg file provided for customing.

'''

__all__ = ('KAYAK ERGO',)

__title__ = 'garden.gauge'
__version__ = '0.2'
__author__ = 'julien@hautefeuille.eu'

import kivy
kivy.require('1.6.0')
from kivy.config import Config
from kivy.app import App
from kivy.clock import Clock
from kivy.properties import NumericProperty
from kivy.properties import StringProperty
from kivy.properties import BoundedNumericProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.widget import Widget
from kivy.uix.scatter import Scatter
from kivy.uix.image import Image
from kivy.uix.label import Label
from os.path import join, dirname, abspath

import serial
from datetime import datetime, timedelta
from math import degrees, radians, cos, sin, asin, sqrt, pi
from tcx import tcx_preamble, tcx_trackpoint, tcx_postamble

class Gauge(Widget):
    '''
    Gauge class

    '''

    unit        = NumericProperty(225/10) # 1 needle tick = 180+45 degrees divided by range
    tacho       = BoundedNumericProperty(0, min = 0, max = 1000,  errorvalue = 1000)
    speed       = BoundedNumericProperty(0, min = 0, max = 15,    errorvalue = 15)
    distance    = BoundedNumericProperty(0, min = 0, max = 50000, errorvalue = 0)
    elapsed     = StringProperty(str(datetime.now()))
    path        = dirname(abspath(__file__))
    file_gauge  = StringProperty(join(path, "lm_tacho_dial_768.png"))
    file_needle = StringProperty(join(path, "lm_tacho_needle_768.png"))
    size_gauge  = BoundedNumericProperty(128, min = 128, max = 600, errorvalue = 128)
    size_text   = NumericProperty(24)

    def __init__(self, **kwargs):
        super(Gauge, self).__init__(**kwargs)

        self._gauge = Scatter(
            size=(self.size_gauge, self.size_gauge),
            do_rotation=False,
            do_scale=False,
            do_translation=False
        )

        _img_gauge = Image(
            source=self.file_gauge,
            size=(self.size_gauge, self.size_gauge)
        )

        self._needle = Scatter(
            size=(self.size_gauge, self.size_gauge),
            do_rotation=False,
            do_scale=False,
            do_translation=False
        )

        _img_needle = Image(
            source=self.file_needle,
            size=(self.size_gauge, self.size_gauge)
        )

        self._speed    = Label(font_size=self.size_text*3, markup=True)
        self._distance = Label(font_size=self.size_text*1.5, markup=True)
        self._elapsed  = Label(font_size=self.size_text*1.5, markup=True)

        self._gauge.add_widget(_img_gauge)
        self._needle.add_widget(_img_needle)

        self.add_widget(self._gauge)
        self.add_widget(self._needle)
        self.add_widget(self._speed)
        self.add_widget(self._distance)
        self.add_widget(self._elapsed)

        self.bind(pos=self._update)
        self.bind(size=self._update)
        self.bind(tacho=self._turn)

    def _update(self, *args):
        '''
        Update gauge and needle positions after sizing or positioning.

        '''
        self._gauge.pos         = self.pos
        self._needle.pos        = (self.x, self.y)
        self._needle.center     = self._gauge.center
        self._speed.center_x    = self._gauge.center_x
        self._speed.center_y    = self._gauge.center_y - (self.size_gauge / 7)
        self._distance.center_x = self._gauge.center_x
        self._distance.center_y = self._gauge.center_y - (self.size_gauge / 4.4)
        self._elapsed.center_x  = self._gauge.center_x
        self._elapsed.center_y  = self._gauge.center_y - (self.size_gauge / 3.4)

    def _turn(self, *args):
        '''
        Turn needle, 1 degree = 1 unit, 0 degree point start on 50 value.

        '''
        self._needle.center_x = self._gauge.center_x
        self._needle.center_y = self._gauge.center_y
        self._needle.rotation = -self.tacho/100 * self.unit
        self._speed.text      = "[color=5599ff][b]{0:.1f}[/b][/color]".format(self.speed)
        self._distance.text   = "[color=99ff55][b]{0:.0f}m[/b][/color]".format(self.distance)
        self._elapsed.text    = "[b]{}[/b]".format(self.elapsed)


if __name__ == '__main__':

    o = {'lat': 53.810016, 'lon':   -1.959652} # oxenhope
    o = {'lat': 21.276500, 'lon': -157.846000} # waikiki

    R = 6371 # earth radius in km
    r = 1.00  # radius used in xy geometry

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

    stepcount = 500
    dtheta    = 2*pi/stepcount # assuming curves have 2*pi periodicity
    theta     = 0
    track     = []
    dist      = 0
    q         = {}

    for step in range(stepcount):
        # calculate xy coordinates and map to geographical.
        # R in km and geometry x,y in km {lat, lon} in degrees
        p = geographical(geometry(theta))

        if theta > 0: # calculate distance to last point
            dist += haversine(p, q)

        track.append({'lat': p['lat'], 'lon': p['lon'], 'dist': dist})
        theta += dtheta
        q = p

    # total lap closes the loop back to the first point from the last
    lap_distance = dist + haversine(q, geographical(geometry(0)))

    # -------------------------------------------------------------------------

    serialport = serial.Serial("/dev/ttyUSB1")
    rev_bytes  = serialport.readline()[:-2]               # strip off last two bytes \r\n
    rev = [0 for x in range(16)]                          # zero all filter values
    if len(rev_bytes) == 4:
        rev = [int(rev_bytes[3])*256*256*256 + int(rev_bytes[2]*256*256) + int(rev_bytes[1]*256) + int(rev_bytes[0])] + rev[:-1]

    time_start = datetime.now()

    timestamps = []
    trackptr   = 0
    lap_count  = 0

    class GaugeApp(App):

        def build(self):
            box = BoxLayout(orientation='horizontal', padding=5)
            self.gauge = Gauge(tacho=0, size_gauge=600, size_text=25)

            box.add_widget(self.gauge)
            Clock.schedule_interval(lambda *t: self.gauge_update(), 0.03)
            return box

        def gauge_update(self):
            global rev, time_start, track, timestamps, trackptr, lap_count, lap_distance

            rev_bytes = serialport.readline()[:-2]               # strip off last two bytes \r\n

            if len(rev_bytes) == 4:
                rev = [int(rev_bytes[3])*256*256*256 + int(rev_bytes[2]*256*256) + int(rev_bytes[1]*256) + int(rev_bytes[0])] + rev[:-1]

                delta = (rev[0]-rev[15])/len(rev) # average = (first element - last element)/num elements = (r0-r1+r1-r2+r2....-rn)/(n+1)

                time_now = datetime.now()

                if delta < 0: # reset must have been pressed
                     rev        = [0 for x in range(len(rev))]
                     delta      = 0
                     time_start = datetime.now()
                     time_now   = time_start
                     distance   = 0
                     timestamps = []
                     trackptr   = 0

                time_delta = time_now - time_start
                hour, remr = divmod(time_delta.seconds, 60*60)
                mins, secs = divmod(remr, 60)

                self.gauge.tacho    = delta * 4 * 60             # rpm = 4 samples/sec * 60 sec
                self.gauge.speed    = self.gauge.tacho/850 * 12  # 850 rpm is 12 kph
                self.gauge.distance = rev[0]/4.8                 # 4.8 revs is about 1 metre
                self.gauge.elapsed  = "{:02d}:{:02d}:{:02d}".format(hour, mins, secs)

                if self.gauge.distance > (track[trackptr]['dist'] + lap_count*lap_distance):
                    timestamps.append({'time': time_now.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3], 'speed': self.gauge.speed, 'dist': self.gauge.distance})
                    trackptr = (trackptr + 1) % len(track)
                    if trackptr == 0:
                        lap_count += 1

    GaugeApp().run()

    # -------------------------------------------------------------------------
    # the app has run, now generate the activity file in tcx format

    max_speed = 0
    for x in timestamps:
        if x['speed'] > max_speed:
            max_speed = x['speed']

    total_distance = timestamps[-1]['dist']                            # taken from the last timestamp
    time_start_str = time_start.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
    time_elapsed   = datetime.now() - time_start
    calories       = 1000*time_elapsed.seconds/3600                    # crude calc: 1000 calories/hour
    elevation      = 0
    average_speed  = total_distance / time_elapsed.seconds

    activity = open('activity_{}.tcx'.format(time_start.strftime("%Y%m%d%H%M")), 'w')
    activity.write(tcx_preamble.format(time_start_str, time_start_str, time_elapsed.seconds, total_distance, max_speed, calories))

    for tp in range(len(timestamps)):
        activity.write(tcx_trackpoint.format(timestamps[tp]['time'], track[tp%stepcount]['lat'], track[tp%stepcount]['lon'], elevation, timestamps[tp]['dist'], timestamps[tp]['speed']))

    activity.write(tcx_postamble.format(average_speed))
    activity.close()

    print("Total distance: {}".format(total_distance))
    hour, remr = divmod(time_elapsed.seconds, 60*60)
    mins, secs = divmod(remr, 60)
    print("Total time: {}:{}:{}".format(hour, mins, secs))
    print("Average speed: {}".format(average_speed))
    print("Total revs: {}".format(rev[0]))
    print("Lap length: {}".format(lap_distance))
    print("Total laps: {}".format(total_distance/lap_distance))
    print("File: {}".format('activity_{}.tcx'.format(time_start.strftime("%Y%m%d%H%M"))))
