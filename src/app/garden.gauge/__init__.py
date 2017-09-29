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
import re
import datetime
from datetime import datetime

class Gauge(Widget):
    '''
    Gauge class

    '''

    unit = NumericProperty(225/10) # 1 needle tick = 180+45 degrees divided by range
    value = BoundedNumericProperty(0, min=0, max=1000, errorvalue=1000)
    path = dirname(abspath(__file__))
    file_gauge = StringProperty(join(path, "lm_tacho_dial_768.png"))
    file_needle = StringProperty(join(path, "lm_tacho_needle_768.png"))
    size_gauge = BoundedNumericProperty(128, min=128, max=600, errorvalue=128)
    size_text = NumericProperty(10)

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

        self._glab = Label(font_size=self.size_text*2, markup=True)
        self._elap = Label(font_size=self.size_text, markup=True)

        self._gauge.add_widget(_img_gauge)
        self._needle.add_widget(_img_needle)

        self.add_widget(self._gauge)
        self.add_widget(self._needle)
        self.add_widget(self._glab)
        self.add_widget(self._elap)

        self.bind(pos=self._update)
        self.bind(size=self._update)
        self.bind(value=self._turn)

    def _update(self, *args):
        '''
        Update gauge and needle positions after sizing or positioning.

        '''
        self._gauge.pos = self.pos
        self._needle.pos = (self.x, self.y)
        self._needle.center = self._gauge.center
        self._glab.center_x = self._gauge.center_x
        self._glab.center_y = self._gauge.center_y - (self.size_gauge / 6)
        self._elap.center_x = self._gauge.center_x
        self._elap.center_y = self._gauge.center_y - (self.size_gauge / 3)

    def _turn(self, *args):
        '''
        Turn needle, 1 degree = 1 unit, 0 degree point start on 50 value.

        '''
        self._needle.center_x = self._gauge.center_x
        self._needle.center_y = self._gauge.center_y
        self._needle.rotation = -self.value/100 * self.unit
        self._glab.text = "[b]{0:.0f}[/b]".format(self.value)
        self._elap.text = "[b]{}[/b]".format(datetime.now().strftime('%H:%M:%S'))


if __name__ == '__main__':

    serialport = serial.Serial("/dev/ttyUSB1")
    activity = open('activity.kyk', 'w')

    class GaugeApp(App):

        def build(self):
            box = BoxLayout(orientation='horizontal', padding=5)
            self.gauge = Gauge(value=0, size_gauge=600, size_text=25)

            box.add_widget(self.gauge)
            Clock.schedule_interval(lambda *t: self.gauge_update(), 0.03)
            return box

        def gauge_update(self):
            hertz = re.findall(r'\d+', str(serialport.readline()))[0]
            self.gauge.value = int(hertz)*60
            activity.write(hertz)
            activity.write("\n")

    GaugeApp().run()
    activity.close()

