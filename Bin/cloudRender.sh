#!/bin/bash
workPath='../Tools/cloudRender/cloudrender-server'
BIN_PATH=$(cd `dirname $0`; cd ../ ; pwd )
cd `dirname $0`
logPath="$PWD/../log"

cd $workPath

source /etc/profile.d/ipvRunnerProfile.sh


Start(){
    [ ! -d "$logPath" ] && mkdir $logPath
    if [ `ps -ef |grep node | grep -v grep | grep cloudRender | wc -l` == 0 ] ;then
         nohup npm run prod >> $logPath/slb.log 2>&1 &
    fi
}

Status(){
   if ps -ef | grep node |grep -v grep | grep  cloudRender > /dev/null  ;then
        exit 0
   else
	exit 1
   fi
}

Stop() {
   if ps -ef | grep node |grep -v grep | grep   cloudRender > /dev/null ;then
       Pid=`ps -ef | grep node |grep -v grep | grep  cloudRender |awk '{print $2}' | tr '\n' ' '`
       [ ! -z "$Pid" ] && kill ${Pid[*]}
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
