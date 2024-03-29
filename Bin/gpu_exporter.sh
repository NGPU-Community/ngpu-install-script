#!/bin/bash
workPath='../Tools/gpu_exporter'
BIN_PATH=$(cd `dirname $0`; cd ../ ; pwd )
cd `dirname $0`
#cd $workPath
logPath="$PWD/../log"
cd $workPath

source /etc/profile.d/ipvRunnerProfile.sh

Start(){
    [ ! -d "$logPath" ] && mkdir $logPath
    if ! pidof gpu_exporter >/dev/null; then
        nohup ./gpu_exporter >> $logPath/gpu_exporter.log 2>&1 &
    fi
    count=0
    until pidof gpu_exporter >/dev/null || [ $count -gt 10 ]; do
        sleep 1
        let count=$count+1;
    done
}

Stop(){
    if pidof gpu_exporter >/dev/null; then
        kill -9 `pidof gpu_exporter`
    fi
}

Status() {
    if pidof gpu_exporter >/dev/null; then
        exit 0
    else
        exit 1
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

