#!/bin/bash
 
nginx=/opt/nginx/sbin/nginx
Pidfile=/opt/nginx/logs/nginx.pid
Start(){
  if [ ! -f $Pidfile ];then
    $nginx
  fi   
}
Stop(){
  if [ ! -f $Pidfile ];then
    echo "nginx in not running"
  else
    $nginx -s stop
  fi
}
Reload(){
  if [ ! -f $Pidfile ];then
    echo "Cat't open $Pidfile ,no such file or directory"
  else
    $nginx -s reload
  fi
}
Status(){
  if [ ! -f $Pidfile ];then
     exit 1
  else
     exit 0
  fi     
}

case "$1" in
    start)
    Start
;;
    status)
    Status
;;
    stop)
    Stop
;;
    reload)
    Reload
;;
    restart)
    Stop
    sleep 2
    Start
;;
    *)
    echo "Usage: sh $0 {start|stop|reload|restart} "   
    exit 1
esac
exit   $RETVAL
