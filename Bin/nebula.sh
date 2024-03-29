#!/bin/bash
workPath='../Tools/nebula/'
BIN_PATH=$(cd `dirname $0`; cd ../ ; pwd )
cd `dirname $0`
logPath="$PWD/../log"

cd $workPath

source /etc/profile.d/ipvRunnerProfile.sh

Start(){
    [ ! -d "$logPath" ] && mkdir $logPath
    if ! pidof nebula >/dev/null; then
        nohup ./nebula -config  ./node.yaml >> $logPath/nebula.log 2>&1 &
    fi
    count=0
    until pidof nebula >/dev/null || [ $count -gt 10 ]; do
        sleep 1
        let count=$count+1;
    done
}

Stop(){
    if pidof nebula >/dev/null; then
        kill -9 `pidof nebula`
    fi
}

Status() {
    if pidof nebula >/dev/null; then
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
