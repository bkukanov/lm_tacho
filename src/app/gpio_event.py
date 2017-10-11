#!/usr/bin/env python

import pigpio
import time

class event_pin:
   def __init__(self, device, gpio):
      self.device = device
      self.gpio   = gpio

      self._watchdog   = 200 # milliseconds
      self._eventcount = 0
      self._last_edge  = None
      self._delta      = None

      device.set_mode(gpio, pigpio.INPUT)
      device.set_glitch_filter(gpio, 200) # microseconds

      self._cb = device.callback(gpio, pigpio.RISING_EDGE, self._cbf)
      device.set_watchdog(gpio, self._watchdog)

   def _cbf(self, gpio, level, now):

      if level == 1: # rising edge

         if self._last_edge is not None:
            self._delta = pigpio.tickDiff(self._last_edge, now)

         self._eventcount += 1
         self._last_edge = now

      elif level == 2: # watchdog timeout

         if self._delta is not None:
            if self._delta < 2000000000: # 2e9
               self._delta += (self._watchdog * 1000)

   def cancel(self):
      # clean up
      self.device.set_watchdog(self.gpio, 0) # stop watchdog
      self._cb.cancel()                      # cease responding

if __name__ == "__main__":

   import time
   import pigpio
   import gpio_event

   GPIO_PIN    = 7
   RUN_TIME    = 120.0
   SAMPLE_TIME = 2.0

   device = pigpio.pi()
   pin = gpio_event.event_pin(device, GPIO_PIN)

   start = time.time()
   while (time.time() - start) < RUN_TIME:

      time.sleep(SAMPLE_TIME)

      print("Time delta={}".format(pin._delta))
      print("Event count={}".format(pin._eventcount))

   # exit cleanly by turning off the pin activities and stopping the device
   pin.cancel()
   device.stop()
