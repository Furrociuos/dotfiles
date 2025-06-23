#!/bin/bash

PHONEID=7ef05741_406d_4ba6_bdcb_148735f3c61d

if pgrep -x "kdeconnectd" > /dev/null; then
    if qdbus org.kde.kdeconnect /modules/kdeconnect/devices/$PHONEID org.kde.kdeconnect.device.isReachable | grep true > /dev/null; then
        echo ' '$(qdbus org.kde.kdeconnect /modules/kdeconnect/devices/$PHONEID/battery org.kde.kdeconnect.device.battery.charge)%
    else
        echo ' '
    fi
else
    echo ' ?'
fi
