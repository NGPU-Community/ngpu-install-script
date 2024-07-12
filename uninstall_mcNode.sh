#!/bin/bash
# data 2022-05-29
# data 2023-09-06
# version 0.2

# 定义一个包含多个项目名称的数组
projects=(nodeListen ipvRunner nebula nanoDownload nginx slb cloudRender node_exporter)

# 定义一个断开连接的URL
disconnect='https://gslb.ngpu.ai/user/nodeDisconnect'

# 打印提示信息，询问是否卸载ngpu
# printf "Are you sure to uninstall ngpu? (y/n)"
# printf "\n"
# read -p "(Default: n):"  -e answer

# 如果用户没有输入，默认为 "n"
# [ -z ${answer} ] && answer="n"
# if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
echo  "remove service please wait...."
# else
    # exit 0
# fi

echo "[*] Removing ngpu"

systemctl stop docker.socket
systemctl stop docker

# 如果存在ipvRunnerProfile.sh文件
if [ -f "/etc/profile.d/ipvRunnerProfile.sh"  ]; then

    # 从ipvRunnerProfile.sh中提取home目录路径
    home=$(cat  /etc/profile.d/ipvRunnerProfile.sh |awk -F'=' '{print $2}' | egrep -o '.*ipvRunner' | sort  -u | head -n 1)
    if [ -d "$home" ]; then

        # 从config.json中提取本地地址
        nodeAddr="$(cat $home/config.json |$home/Bin/jq  -r '.localAddr')"

        # 停止各个项目
        for i in ${projects[*]}; do
            [ -f "$home/Bin/${i}.sh" ] && $home/Bin/${i}.sh stop
            if [ -f "/etc/systemd/system/${i}.service" ]; then
                rm -f /etc/systemd/system/${i}.service
	    fi
        done

        # 删除home目录及其内容
        echo "[*] Removing $home directory"
        rm -rf $home

        # 使用dirname命令获取上一级目录
        parent_dir=$(dirname "$home")

        # 删除home目录及其内容
        rm -rf $parent_dir

        systemctl daemon-reload
        systemctl reset-failed
    fi

    # 在.bashrc文件中查找是否包含vulkan设置
    if grep vulkan ~/.bashrc >/dev/null ;then

        # 移除.bashrc中的vulkan设置
        sed -i '/vulkan\/setup-env.sh/d'  ~/.bashrc
    fi
    rm -f /etc/profile.d/ipvRunnerProfile.sh

    # 如果存在/opt/nginx目录，删除之
    [ -d "/opt/nginx" ] && rm -rf /opt/nginx

    # 删除包含home路径的crontab任务
    crontab -l | grep -v "$home" | crontab -
fi

# 如果nodeAddr变量不为空
if [ ! -z "$nodeAddr" ]; then

    # 构建JSON数据
    apiData='{"nodeAddr":"'"$nodeAddr"'"}'

    # 发送API请求并获取返回数据
    returnData=$(curl -s -H "Content-Type: application/json" -X POST -d  "${apiData[*]}" --insecure $disconnect)
    if  echo ${returnData[*]} | grep  200 >/dev/null; then

        # 如果API请求成功，打印成功消息
	    echo '[SUCCEEDED] api request ok'
    else

        # 如果API请求失败，打印错误消息
        echo "[ERROR] api request failed : $disconnect"
        echo -e  "${returnData[*]}"
    fi
fi

#for docker daemon
if [ -f "/etc/docker/daemon.json" ]; then
	rm -f "/etc/docker/daemon.json"
fi

# 打印卸载完成的消息
echo "[*] Uninstall complete"
