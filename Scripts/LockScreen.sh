#!/bin/bash

swaylock -i '~/.config/swaylock/lockscreen.jpg' \
  --ignore-empty-password \
  --daemonize \
  --indicator \
  --clock \
  --timestr "%H:%M" \
  --datestr "%b-%d-%Y" \
  --show-failed-attempts \
  --font 'CascadiaCode' \
  --font-size '24'
