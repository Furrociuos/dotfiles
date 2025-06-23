#!/bin/bash

nwg-drawer -term ghostty \
  -c 6 \
  -fm nautilus \
  -pbpoweroff 'shutdown now' \
  -pbreboot 'reboot' \
  -pbexit 'hyprctl dispatch exit' \
  -pblock 'sh ~/Scripts/LockScreen.sh' \
  -pbsleep 'systemctl suspend'
