#!/bin/bash
workPath='../Tools/slb/'
BIN_PATH=$(cd `dirname $0`; cd ../ ; pwd )
cd `dirname $0`
logPath="$PWD/../log"

cd $workPath

source /etc/profile.d/ipvRunnerProfile.sh


Start(){
    [ ! -d "$logPath" ] && mkdir $logPath
    if [ `ps -ef |grep node | grep -v grep | grep -w 8090 | wc -l` == 0 ] ;then
         npm run prod port 8090 >> $logPath/slb.log 2>&1 &
    fi
}

Status(){
   if ps -ef | grep node |grep -v grep | grep -w 8090 > /dev/null  ;then
        exit 0
   else
	exit 1
   fi
}

Stop() {
   if ps -ef | grep node |grep -v grep | grep -w  8090 > /dev/null ;then
       Pid=`ps -ef | grep node |grep -v grep | grep -w  8090 |awk '{print $2}' | tr '\n' ' '`
       [ ! -z "$Pid" ] && kill -9 ${Pid[*]}
   fi
}

case $1 in
   start)
       Start
       ;;
   stop)
       Stop
       ;;
   restart)
       Start
       Stop
       ;;
   status)
       Status
       ;;
     *)
       echo "$0 [start|stop|restart]"
       ;;
esac
