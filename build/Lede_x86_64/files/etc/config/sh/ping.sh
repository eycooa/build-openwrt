
#代码说明：
#通过调用shell函数pingcmd，实现ping设置在severX中的IP地址代表的主机。
#分析下pingcmd函数的实现：
#prefix="SERVER $1 PING $2"    //定义一个字符串，为后面printf输出做准备
#ping -w 1 -c 1 $2>/dev/null
#//调用ping函数，-w为超时时间；-c为ping的次数;
#ping -w 1 -c 1 $2 
#从脚本所在机去ping之后pingcmd函数的第二个参数(本例为之后建立的serve1-7),超时1秒，执行1次
#>/dev/null 的作用是把屏幕的输出从指向到某处，/dev/null是指向空设备，即不需要标准输出。
#ret=$?  //获取返回值，0为ping成功
#if [ $ret -eq 0 ]    //如果返回值为0,即ping成功
#then printf "$prefixt is good"   则输出一开始定义的字符串（例：SERVER 192.168.1.3 PING 192.168.1.2 OK）
#else printf "$prefixt is down" 同上，输出错误信息（此处删除标准输出，之前已定义了输）。
#fi


#!/bin/sh
#filename ping.sh
pingcmd()
{
prefix="SERVER $1 PING $2"
ping -w 1 -c 1 $2>/dev/null
ret=$?
if [ $ret -eq 0 ]
then printf "$prefix is good \n" > /etc/config/sh/ping.log
else printf "$prefix is down \n"> /etc/config/sh/ping123.1.log&&ping 192.168.123.1 -w 1 >> /etc/config/sh/error.log&&ifup wan
fi
return 0
}
echo "---begin check host ---"
server0="192.168.123.1"
server1="223.5.5.5"
pingcmd $server0 $server0
pingcmd $server0 $server1
echo ""
