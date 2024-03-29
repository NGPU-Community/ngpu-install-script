#!/bin/bash
workPath='../'
BIN_PATH=$(cd `dirname $0`; cd ../ ; pwd )
cd `dirname $0`
cd $workPath
logPath="$PWD/log"

source /etc/profile.d/ipvRunnerProfile.sh

Start(){
    [ ! -d "$logPath" ] && mkdir $logPath
    if ! pidof nodeListen >/dev/null; then
        nohup ./nodeListen >> ./log/nodeListen.log 2>&1 & 
    fi
    count=0
    until pidof nodeListen >/dev/null || [ $count -gt 10 ]; do
        sleep 1
        let count=$count+1;
    done
}

Stop(){
    if pidof nodeListen >/dev/null; then
        kill -9 `pidof nodeListen`
    fi
}

Status() {
    if pidof nodeListen >/dev/null; then
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
