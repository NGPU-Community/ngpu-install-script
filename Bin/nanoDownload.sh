#!/bin/bash
workPath='../'
BIN_PATH=$(cd `dirname $0`; cd ../ ; pwd )
cd `dirname $0`
cd $workPath
logPath="$workPath/log"

source /etc/profile.d/ipvRunnerProfile.sh

Start(){
    [ ! -d "$logPath" ] && mkdir $logPath
    if ! pidof nanodownload >/dev/null; then
        nohup ./nanodownload >> ./log/nanodownload.log 2>&1 & 
    fi
    count=0
    until pidof nanodownload >/dev/null || [ $count -gt 10 ]; do
        sleep 1
        let count=$count+1;
    done
}

Stop(){
    if pidof nanodownload >/dev/null; then
        kill -9 `pidof nanodownload`
    fi
}

Status() {
    if pidof nanodownload >/dev/null; then
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
