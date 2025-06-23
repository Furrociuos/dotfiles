#!/bin/bash

nwg-wrapper -s date.sh -c date.css -r 180000 \
  -j center -a start -p left \
  -ml 323 -mt 235 &
nwg-wrapper -s day.sh -c day.css -r 180000 \
  -j center -a start -p left \
  -ml 213 -mt 125
