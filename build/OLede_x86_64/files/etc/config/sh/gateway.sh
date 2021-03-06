#!/bin/sh
ip=`traceroute -m 1 240c::6666 |grep 'ms'|awk -F ')'  '{print $1}'|grep -v deprecated|awk -F '('  '{print $2}'` || die "$ip"
route -A inet6 add default gw $ip
