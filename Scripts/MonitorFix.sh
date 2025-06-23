#!/bin/bash

case $1/$2 in
post/*)
  # Rebind Intel GPU
  echo echo "0000:00:02.0" >/sys/bus/pci/drivers/i915/unbind
  echo "0000:00:02.0" >/sys/bus/pci/drivers/i915/bind
  ;;
esac
