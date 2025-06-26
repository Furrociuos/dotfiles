#!/bin/bash

killall steam ||
  steam-native -gamepadui -system-composer
#  gamemoderun gamescope -f -e -w 1920 -h 1080 -r 165 --backend sdl --force-grab-cursor --prefer-vk-device 8086:a7a8 --mangoapp -- steam-native -gamepadui -steamos3
