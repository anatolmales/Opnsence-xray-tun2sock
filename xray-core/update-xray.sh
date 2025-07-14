#!/bin/sh

wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat -O /usr/local/share/xray-core/geoip.dat
wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat -O /usr/local/share/xray-core/geosite.dat
/usr/local/etc/rc.d/xray restart
