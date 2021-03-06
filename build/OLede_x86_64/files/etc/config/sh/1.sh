#!/bin/sh
#参数N表示你申请几M宽带（ADSL），2M就填2，4M就填4，以此类推,N只能为正整数。IPS是开始IP地址，IPE是结束IP地址。其它参数都可以不填。
#对于小区宽带（或自己想依据实际情况修改），UP和DOWN分别表示总带宽的上行和下行，UPLOADC和DOWNLOADC是单机的最大上行和下行。
#建议UPLOADC<=40%UP,DOWNLOADC<=70%DOWN,如果共享电脑比较多，可修改得更小一点。
#实际p2p下载时，最大值有可能超过DOWNLOADC，因为“小包”和web下载还有额外的带宽。所有带宽动态共享。
#NTCP和NUDP分别是单机TCP和UDP连接数限制(常见端口如53,80等不受限制）
IPS=2
IPE=254
N=280
NTCP=60
NUDP=100
DOWN=$(($N * 90))mbps
DOWNLOADC=$(($N*90*60/100))mbps
UP="40mbps"
UPLOADC="16mbps"
#下面参数已经自动依据N值计算(一般不需要修改)
DOWN2R=$(($N*90*35/100))mbps
DOWN2C=$(($N*90*80/100))mbps
DOWN3R=$(($N*90*5/100))mbps
DOWN3C=$(($N*90*40/100))mbps
DOWNLOADR=$(($N*90*60/100/$(($IPE-IPS+1))))mbps
UP2R="14mbps"
UP2C="20mbps"
UP3R="1mbps"
UP3C="8mbps"
UPLOADR="16mbps"
UIP="192.168.123."
NET="192.168.123.0/24"
UPSP=:128
DOWNSP=:512

#装载核心模块,创建QOS专用链
insmod imq
insmod  ipt_IMQ
ifconfig imq1 up
ifconfig imq0 up
insmod ipt_length.o
iptables -t mangle -N QOSDOWN
iptables -t mangle -N QOSUP
iptables -t mangle -I FORWARD -d $NET -j QOSDOWN
iptables -t mangle -I FORWARD -s $NET -j QOSUP
iptables -t mangle -A QOSDOWN -j IMQ --todev 0
iptables -t mangle -A QOSUP -j IMQ --todev 1

#单机限制TCP连接数50，UDP连接数80，并且对53,80等端口例外
iptables -t mangle -N LMT
iptables -t mangle -N UDPLIMIT
iptables -t mangle -I PREROUTING -i br0 -j LMT
iptables -t mangle -A LMT -p tcp --syn -m connlimit --connlimit-above $NTCP --connlimit-mask 32 -j DROP
iptables -t mangle -A LMT -p ! tcp -m connlimit --connlimit-above $NUDP --connlimit-mask 32 -j UDPLIMIT
iptables -t mangle -A UDPLIMIT -m state --state NEW -j DROP
iptables -t mangle -I LMT -s $NET -p udp -m mport --dports 53 -j RETURN
iptables -t mangle -I LMT -s $NET -p tcp -m mport --dports 20:23,25,53,80,110,443 -j RETURN

#根队列初始化
tc qdisc del dev imq0 root
tc qdisc del dev imq1 root
tc qdisc add dev imq0 root handle 1: htb
tc qdisc add dev imq1 root handle 1: htb
tc class add dev imq1 parent 1: classid 1:1 htb rate $UP
tc class add dev imq0 parent 1: classid 1:1 htb rate $DOWN
#特殊队列(小包,http)初始化
tc class add dev imq0 parent 1:1 classid 1:2 htb rate $DOWN2R ceil $DOWN2C prio 0
tc class add dev imq0 parent 1:1 classid 1:3 htb rate $DOWN3R ceil $DOWN3C prio 7
tc filter add dev imq0 parent 1:0 protocol ip handle 2 fw flowid 1:2
tc filter add dev imq0 parent 1:0 protocol ip handle 3 fw flowid 1:3
iptables -t mangle -A QOSDOWN -m length --length $DOWNSP -j MARK --set-mark-return 2
iptables -t mangle -A QOSDOWN -p tcp -j BCOUNT
iptables -t mangle -A QOSDOWN -p tcp -m mport --sports 80,443 -m bcount --range :307200 -j MARK --set-mark-return 2
iptables -t mangle -A QOSDOWN -p tcp -m mport --sports 80,443 -m bcount --range 307201: -j MARK --set-mark-return 3
tc class add dev imq1 parent 1:1 classid 1:2 htb rate $UP2R ceil $UP2C prio 0
tc class add dev imq1 parent 1:1 classid 1:3 htb rate $UP3R ceil $UP3C prio 7
tc filter add dev imq1 parent 1:0 protocol ip handle 2 fw flowid 1:2
tc filter add dev imq1 parent 1:0 protocol ip handle 3 fw flowid 1:3
iptables -t mangle -A QOSUP -m length --length $UPSP -j MARK --set-mark-return 2
iptables -t mangle -A QOSUP -p tcp -j BCOUNT
iptables -t mangle -A QOSUP -p tcp -m mport --dports 80,443 -m bcount --range :204800 -j MARK --set-mark-return 2
iptables -t mangle -A QOSUP -p tcp -m mport --dports 80,443 -m bcount --range :204801 -j MARK --set-mark-return 3

#所有普通IP单独限速
i=$IPS; 
while [ $i -le $IPE ] 
do
tc class add dev imq1 parent 1:1 classid 1:1$i htb rate $UPLOADR ceil $UPLOADC prio 2
tc qdisc add dev imq1 parent 1:1$i handle 1$i: sfq perturb 15
tc filter add dev imq1 parent 1:0 protocol ip handle 1$i fw classid 1:1$i 
tc class add dev imq0 parent 1:1 classid 1:1$i htb rate $DOWNLOADR ceil $DOWNLOADC prio 2
tc qdisc add dev imq0 parent 1:1$i handle 1$i: sfq perturb 15
tc filter add dev imq0 parent 1:0 protocol ip handle 1$i fw classid 1:1$i
iptables -t mangle -A QOSUP -s $UIP$i -j MARK --set-mark-return 1$i
iptables -t mangle -A QOSDOWN -d $UIP$i -j MARK --set-mark-return 1$i
i=`expr $i + 1` 
done