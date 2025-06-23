#!/bin/bash

pkill nwg-wrapper ||
  nwg-wrapper -s date.sh -c date.css -r 180000 \
    -j center -a start -p left \
    -ml 160 -mt 125
