#!/bin/bash

log_dir_name=`date +%Y\-%m`
log_time=`date +%F -d -1day`
yesterday_dir=`date +%Y\-%m -d -1day`
#get log path
home=$(cat /etc/profile.d/ipvRunnerProfile.sh |awk -F'=' '{print $2}' | egrep -o '.*ipvRunner' | sort  -u)
files=$(ls $home/log  |  grep -v  "20[0-9][0-9]" | grep -v nodeListen)

tar_log(){
    cd $home/log
    tar -zcvf ${log_time}.tar.gz *20[0-9][0-9][0-9]*  *${log_time}.log  --remove-files
    mv ${log_time}.tar.gz ${yesterday_dir}/
}

while read line; do
    cp $home/log/$line $home/log/$line-${log_time}.log
    >$home/log/$line
    cd $home/log
    if [ ! -d "${log_dir_name}" ];then
        mkdir ${log_dir_name}
    fi
done <<EOF
${files[*]}
EOF

tar_log
