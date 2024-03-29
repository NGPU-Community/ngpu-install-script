#!/bin/bash
# 2022-05-18
# 2022-11-20
# 2023-09-07
#version 0.3

# Install example: 
#./install_mcNode.sh --nodeAddr 0xf9cfaa04f5c56577944cb1651ce77c07ede74c01 --nodeName AAA-node --ipAddr 192.168.15.3 --home /home/ipolloverse --storage 100

# 
configUrl='https://ecotoolstest.ipolloverse.com:8443/ipvConfigML/ipvConfig?nodeAddr='

# Installation package 
softUrl='https://ecotools.ipolloverse.com:81'

# API
apiPostUrl='https://gslb.ipolloverse.cn'

# 
deployerSpace=2 #unit GB

# 
port1=7777
port2=11111

# port 
portS=($port1 $port2 8070 8071 8080 8081 8082 8084 8096 8097 8090 8890)

#help information
Help(){	
    # 
    echo -e "\nUsage: sh $0 [OPTION]"
    # 
    echo -e "Options:"
    # 
    echo -e "[OPTION]"
    # 
	echo -e "[ --nodeAddr ]   node address from registration page       e.g. a3c46471cd252903f784dbdf0ff426f0d2abed47 "
    # 
	echo -e "[ --nodeName ]   node name                                 e.g. zhangsan-node"
    # 
	echo -e "[ --ipAddr   ]   local ip to public area                   e.g. 192.168.1.100 "
    # 
	echo -e "[ --home     ]   Installation Path                         e.g. /home/user/ipolloverse/"
    # 
	echo -e "[ --storage  ]   Commitment disk size default unit GB      e.g. 500"
    # 
	echo -e "[ -h|--help  ]   display this help and exit \n"
}

#print log
scriptsLog() {
    # 
    statusCode=$1
    # 
    logInfo=$2
    #   
    if [ $statusCode == 0 ]; then
        echo -e "[\033[32m SUCCESS \033[0m]:\t${logInfo[*]}"
    # 
    elif [ $statusCode == 1 ]; then
        echo -e "[   INFO  ]:\t${logInfo[*]}"
    # 
    elif [ $statusCode == 2 ]; then
        echo -e "[\033[33m   WARN  \033[0m]:\t${logInfo[*]}"
    #  
    elif [ $statusCode == 3 ]; then
        echo -e "\033[41;37m[   ERROR ] \033[0m\t${logInfo[*]}"
        tag=1
    fi
}

# Disable selinux
disableSelinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0 >/dev/null
    fi
}

# 
ChkPort(){
    # 
    port=$1
    # 
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        # 
        if [ ! -z "$(ss -ntlp | grep -w :$port)" ]; then
            scriptsLog 3 "[port:$port]  is already used in the system : $port"
        # 
        elif [  $port -le 5000 -o  "$port" -ge 65535 ];then
            scriptsLog 3 "[port:$port] range of ports is 5000 - 65535 : $port"
        fi
    # 
    else
        scriptsLog 3 "[port:$port] port only of integer" 
    fi
}

# 
EnvChk() {
    # 
    tag=0
    
    # 
    scriptsLog 1 "Start checking the parameters you entered..."
    
    # 
    [ $(id -u) != "0" ] && scriptsLog 3 "Please run the script as root user" 
    
    # 
    if ! which curl >/dev/null; then
        scriptsLog 3 "This script requires \"curl\" utility to work correctly"
    fi

    # 
    if [ -z "$nodeAddr" ];then
        scriptsLog 3 "[nodeAddr]  parameter cannot be empty"
    fi

    # 
    local status=$(curl -I -m 30  -o /dev/null -s -w %{http_code} ${configUrl}${nodeAddr})
    if [ "$status" == 200 ]; then
        jsonConfig=$(curl -s ${configUrl}${nodeAddr})
    else
        scriptsLog 3 "http status code not 200 "${configUrl}${nodeAddr}" \n $(curl -s ${configUrl}${nodeAddr})"
        Help
        exit
    fi
      
    # 
    apiTime=$(echo ${jsonConfig} | egrep -o 'time\":[0-9]+' | egrep -o '[0-9]+')
    timeDiff=$(expr $(date '+%s') - $apiTime)
    if [ $timeDiff -gt 60 -o $timeDiff -lt -60 ]; then
        scriptsLog 3 "Please sync server time, node local time: $(date "+%Y-%m-%d %H:%M:%S"), ${timeDiff} seconds difference from IpvRunner server"
    fi

    # 
    [ -z "$ipAddr" ] &&  scriptsLog 3 "[ipAddr] cannot be empty"
      
    # 
    [ -z "$nodeName" ] && scriptsLog 3 "[nodename] cannot be empty"

    # 
    [ $port1 == $port2 ] && scriptsLog 3 "[port1:$port1] and [port2:$port2] are repeated"

    # 
    for i in ${portS[*]}; do
        if [ "$(echo $i |tr '-' ' ' |wc -w)" == 1 ];then 
           ChkPort $i
        elif [ "$(echo $i |tr '-' ' ' |wc -w)" == 2 ];then
	   portStart=$(echo $i |awk -F'-' '{print $1}')
	   portEnd=$(echo $i |awk -F'-' '{print $2}')
           for ((p=$portStart; p<=$portEnd; p ++));do
                ChkPort $p
           done
        fi
    done
   
    # 
    if [ -z "$home" ];then
        scriptsLog 3 "[home] The installation path cannot be empty"
	    Help
	    exit
    fi

    # 
    if [ ! -d $home ]; then 
        mkdir -p $home
	    scriptsLog 2 "[home] directory does not exist, it has been created for you"
    fi

    # 
    deployerSpace=${deployerSpace%.*}
    if echo "$deployerSpace" | grep  '[^0-9]' >/dev/null; then
        scriptsLog 3 "program installation integer type"
    fi

    if [ -z "$storage" ];then 
        scriptsLog 3 "[home] storage size cannot be empty"
    else
        storage=${storage%.*}
        if echo "$storage" | grep -v '[^0-9]' >/dev/null ;then
            local tmp=$(expr $storage + ${deployerSpace})
            local pathFree=$(df  $home | tail -n 1 |awk '{print $4}')
            if [ $( expr ${pathFree} / 1024 / 1024 ) -lt $tmp ]; then
                scriptsLog 3 "The current directory is out of space, $home  free $(expr ${pathFree} / 1024 / 1024)GB ,Space required for program installation ${deployerSpace}GB, The size of the allocated space is $storage GB"
            fi
        else
            scriptsLog 3 "[storage] type is int ${storage}"  
        fi
    fi    
    
    # 
    if [ $tag == 0 ]; then 
        scriptsLog 0 "Parameter check succeeded"
    else
        scriptsLog 3 "The parameter check failed, please check it and try again"
        Help
        exit
    fi
}

# 
getIp() {
    # 
    # ip addr：
    # egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'：
    # egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\."：
    # head -n 1：
    IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v	"^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)
	# 
    # check ip, if blank, get public ip from "ipinfo.io" 
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )

    # check ip, if blank, get public ip from "cip.cc" 
    [ -z ${IP} ] && IP=$( curl -s cip.cc | grep IP | awk '{print $3}' )
}

# 
confInfo(){
    EnvChk
    getIp
    echo -e "\nInformation confirmed"
    echo -e "Your nodeAddr        : \033[32m ${nodeAddr} \033[0m"
    echo -e "Your nodeName        : \033[32m ${nodeName} \033[0m"
    echo -e "Your local ipAddr    : \033[32m ${ipAddr} \033[0m"
    echo -e "Your public ipAddr   : \033[32m ${IP} \033[0m"
    echo -e "Your install path    : \033[32m ${home} \033[0m"
    echo -e "Your storage size    : \033[32m ${storage} \033[0m"
    echo
    printf "Are you sure install ? (y/n)"
    printf "\n"
    read -p "(Default: n):" -e answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        scriptsLog 1 "Install service please wait...."
    else
        exit 0
    fi
}

# 
downloadFile() {
   
    local downloadUrl=$1    # 
    local savePath=$2       # 
    local fileName=$3       # 
    local progress=$4       # 
    local fileType=${fileName#*.}   # 

    #[ ${fileType} == 'tar.gz' -o ${fileType} == 'tar' ] && return 0
    
    # 
    [ -z "${progress}" ] && options='-s' || options='-L --progress-bar'

    # 
    [ -f "/tmp/${fileName}" ] && mv /tmp/${fileName} /tmp/${fileName}.bak
	
    # 
    local status=$(curl -I -m 30 -o /dev/null -s -w %{http_code} $downloadUrl)

    #  200
    if [ "$status" != 200 ]; then
        scriptsLog 3 "downloading: http status code not 200 "$downloadUrl" \n $(curl -s $downloadUrl)"
        Help    # 
        exit    # 
    fi
	
    #  /tmp/${fileName}
    if ! curl ${options[*]} "$downloadUrl" -o /tmp/${fileName}; then
        scriptsLog 3 "Can't download ${projectName} file to /tmp/"
        exit 3
    fi

    # 
    [ ! -d "$savePath" ] && mkdir -p $savePath

    # 
    if [ ${fileType} == 'tar.gz' -o ${fileType} == 'tar' ];then

        # 
        if ! tar xf /tmp/${fileName} -C ${savePath};then
            scriptsLog 3 "Can't unpack /tmp/${fileName} to ${savePath} directory"
        fi
    else
        # 
        \cp /tmp/${fileName} $savePath
    fi

    # 
    rm -f /tmp/${fileName}
}

# 
createProject() {

    local name=$1   # 
    local After=$2  # 

    # systemd 
    scriptsLog 1 "create $name systemd service"
    if [ ! -f "$home/ipvRunner/Bin/${name}.sh" ]; then  # 
        # 
        scriptsLog 3 "create $name no startup script"
        # 
        scriptsLog 2 "[$name]  Please contact your system administrator"
        # 
        exit 2
    fi

    # 
    cat >/tmp/$name.service <<EOL
[Unit]
Description=$name service
After=network.target ${After[*]}

[Service]
Type=forking
ExecStart=$home/ipvRunner/Bin/${name}.sh start
ExecReload=$home/ipvRunner/Bin/${name}.sh restart
ExecStop=$home/ipvRunner/Bin/${name}.sh stop

[Install]
WantedBy=multi-user.target
EOL
    # 
    if [ $name == 'cloudRender' ];then
        # 
        sed -i "8i PIDFile\=$home/ipvRunner/Tools/cloudRender/cloudrender-server/logs/server-0.pid" /tmp/${name}.service 
        sed -i "8i Environment=PM2_HOME=/root/.pm2" /tmp/${name}.service 
    fi

    # 
    mv -bf /tmp/${name}.service /etc/systemd/system/${name}.service

    # 
    systemctl daemon-reload
	
    # 
    if $home/ipvRunner/Bin/${name}.sh status ; then
        scriptsLog 2 "Stop the already running process $name"
	$home/ipvRunner/Bin/${name}.sh stop # 
    fi

    # 
    scriptsLog 1 "Configure $name system  startup"
    # 
    systemctl enable ${name}.service >/dev/null 2>&1
    # 
    systemctl start ${name}.service >/dev/null 2>&1
    # 
    if ! systemctl status ${name}.service >/dev/null; then
        scriptsLog 3 "Startup failed [$name]"
        scriptsLog 2 "[$name]  Please contact your system administrator"
        exit 2
    else
        scriptsLog 1 "startup SUCCESS [$name]"
    fi
}

# 
envInit(){
    # 
    scriptsLog 1 "download project file"
    downloadFile $softUrl/tools/ipolloML/ipvRunner.tar.gz "$home"  "ipvRunner.tar.gz" "progressTrue"

    # 
    downloadFile $softUrl/tools/jq "$home/ipvRunner/Bin/"  "jq"
    chmod +x $home/ipvRunner/Bin/jq
    
    # 
    >/tmp/ipvRunnerProfile.sh

    # 
    for((i=0;i<$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq  '.apps | length');i++)); do
        local appName=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[$i].appName")
        local appUrl=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[$i].url")
        local appId=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[$i].appId")
        local appDownloadFile=$(echo ${appUrl##*/})
        scriptsLog 1 "downloaded $appName modules"
        downloadFile $appUrl "${home}/ipvRunner/Business/"  "$appDownloadFile"  "progressTrue"
        
        scriptsLog 1 "add  $appName modules path to system PATH"
        echo "#apps ${appName}" >>/tmp/ipvRunnerProfile.sh
        echo "export PATH=${home}/ipvRunner/Business/${appId}:\$PATH" >>/tmp/ipvRunnerProfile.sh
        echo >>/tmp/ipvRunnerProfile.sh
    done
    
    # 
    for i in $(ls $home/ipvRunner/TestTools); do
        scriptsLog 1 "add  $i modules path to system PATH"
        echo "#apps ${i}" >>/tmp/ipvRunnerProfile.sh
        echo "export PATH=${home}/ipvRunner/TestTools/$i:\$PATH" >>/tmp/ipvRunnerProfile.sh
        echo >>/tmp/ipvRunnerProfile.sh
    done
    
    # 
    for i in  $( ls $home/ipvRunner/Tools/ ); do
        scriptsLog 1 "add  $i modules path to system PATH"
        echo "#apps ${i}" >>/tmp/ipvRunnerProfile.sh
        echo "export PATH=${home}/ipvRunner/Tools/$i:\$PATH" >>/tmp/ipvRunnerProfile.sh
        echo  >>/tmp/ipvRunnerProfile.sh
    done

    # 
    scriptsLog 1 "add  nodejs  modules path to system PATH"
    echo "#nodejs" >>/tmp/ipvRunnerProfile.sh
    echo "export NODE_HOME=${home}/ipvRunner/Tools/node" >>/tmp/ipvRunnerProfile.sh
    echo "export PATH=\$NODE_HOME/bin:\$PATH" >>/tmp/ipvRunnerProfile.sh
    
    # 
    [ ! -d "$home/ipvRunner/log" ] && mkdir -p $home/ipvRunner/log
    
    # 
    chmod 755 -R $home/ipvRunner
    chmod +x /tmp/ipvRunnerProfile.sh
    # /etc/profile.d/ipvRunner.sh
    scriptsLog 1 "Adding project script to /etc/profile.d/ipvRunnerProfile.sh"
    # /etc/profile.d/
    \cp  /tmp/ipvRunnerProfile.sh /etc/profile.d/ipvRunnerProfile.sh    
    # 
    source /etc/profile.d/ipvRunnerProfile.sh
}

# 
writeConfig() {
    # 
    echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.bridge' | sed -r "s/xxxx/$port1/g" >$home/ipvRunner/config.json
}

# 
ipvRunner() {
    scriptsLog 1 "start configure IpvRunner"
    # 
    cpu=$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c)
    # 
    nodeType=0
    # 
    echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.ipvRunner' | $home/ipvRunner/Bin/jq \
        --arg v1 "$ipAddr" \
        --arg v2 "$home/ipvRunner" \
        --arg v3 "$port1" \
        --arg v4 "$port2" \
        --arg v5 "$nodeName" \
        --arg v6 "$storage" \
        --arg v7 "$nodeType" \
	--arg v8 "$cpu" \
        --argjson data "$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -c '.apps')" \
	'.ip=$v1 | .homeFolder=$v2 | .cpu=$v8 | .port1=($v3|tonumber) | .port2=($v4|tonumber) | .nodeName=$v5 | .storage=($v6|tonumber) | .nodeType=($v7|tonumber) | .apps=$data' >$home/ipvRunner/ipvrunner.json
    # 
	createProject nodeListen service
    # 
	[ ! -d "~/.config/autostart/" ] && mkdir -p  ~/.config/autostart/
    # 
    cat > ~/.config/autostart/ipvRunner.desktop <<EOL
[Desktop Entry]

Type=Application

Exec=$home/ipvRunner/Bin/ipvRunner.sh start
EOL
	# 
	$home/ipvRunner/Bin/ipvRunner.sh start
}

# 
cutLog() {
    scriptsLog 1 "Create cron cut log"
    crontab -l | grep -v  cut_log > conf ; echo "01 00 * * *  $home/ipvRunner/Bin/cut_log.sh" >> conf && crontab conf && rm -f conf
}

# install curl
CURL() {
    scriptsLog 1 "start install curl"
    # 
    if ! command -v curl &> /dev/null; then
        sudo apt update
        sudo apt install -y curl
    fi
    # 
    scriptsLog 0  "curl installed"
}

#
nodeListen() {
    scriptsLog 1 "start configure nodeListen "
    # 
    createProject nodeListen
}


NVIDIA() {
    scriptsLog 1 "start install NVIDIA && CUDA"
    # 
    if ! nvidia-smi &> /dev/null; then
        # 
        # 
        sudo add-apt-repository ppa:graphics-drivers/ppa
        # 
        sudo apt-get update
        # 
        sudo apt-get install -y nvidia-driver-525
        # 
        sudo apt-get install -y cuda-12.0
    fi
    scriptsLog 0 "NVIDIA && CUDA installed"
}


#change docker storage path to $home/ipvRunner/ipvTemp/dockerStorage
dockerPath() {
    scriptsLog 1 "start configure docker "
    local dockerStorage="$home/ipvRunner/ipvTemp/dockerStorage"
    local dockerConfig="/etc/docker/daemon.json"
    mkdir -p $dockerStorage

    local dataAll='{"data-root": "'"$dockerStorage"'"}'
    local data=',"data-root": "'"$dockerStorage"'"'
    #echo "to be inserted to daemon: $data"

    if [ -f "$dockerConfig" ]; then
	    #echo "$dockerConfig existed"
	    local content=$(cat "$dockerConfig")
	    #echo  "existed daemon: $content"
	    local last_brace_position=$(grep -b -o "}" "$dockerConfig" | tail -n1 | cut -d':' -f1)
	    local before_last_brace=${content:0:last_brace_position-1}
	    #echo "before_last_brace=$before_last_brace"
	    local after_last_brace=${content:last_brace_position}
	    #echo "after_last_brace=$after_last_brace"

	    local new_content="$before_last_brace $data $after_last_brace"
            echo "$new_content" > "$dockerConfig"
    else
	    #echo "$dockerConfig doesn't existed"
	    echo "$dataAll" | tee "$dockerConfig" >/dev/null
    fi

    sudo systemctl unmask docker.service
    #restart docker 
    sudo systemctl restart docker
    scriptsLog 0 "finished configure docker "
}

# 
Docker() {
    scriptsLog 1 "start install Docker"
    docker_version="5:20.10.21~3-0~ubuntu-focal"
    # 
    if ! command -v docker &> /dev/null; then
        # 
        # 
        sudo apt update
        if [ -f "/usr/share/keyrings/docker-archive-keyring.gpg" ]; then
                rm -f "/usr/share/keyrings/docker-archive-keyring.gpg"
        fi

        # 
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        # 
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        # 
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        # 
        sudo apt update
        sudo apt install -y docker-ce=$docker_version docker-ce-cli=$docker_version containerd.io
        # 
	    sudo systemctl unmask docker.service
        sudo systemctl start docker
        sudo systemctl enable docker
        # 
        sudo usermod -aG docker $USER
        # 
        docker --version
        # 
        local dockerPath=$home/ipvRunner/ipvTemp/dockerStorage
        sudo mkdir -p $dockerPath
        # 
        echo '{"data-root": "'"$dockerPath"'"}' | sudo tee /etc/docker/daemon.json > /dev/null

    else
		dockerPath
    fi
    sudo systemctl restart docker
    # 
    scriptsLog 0  "Docker installed"
}

# 
nvidia_docker() {
    scriptsLog 1 "start install nvidia-docker"

    # 
    local version="2.13"
    local installed_version="$(docker --version | awk '{print $3}' | cut -d ',' -f1)"
    if [ "$installed_version" != "$version" ]; then

        sudo apt update
        #sudo apt install -y docker.io
	if [ -f "/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg" ]; then 
		rm -f "/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
	fi
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        apt update
        apt install -y nvidia-docker2

        # 
        # if curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | sudo apt-key add - &&
        #     distribution=$(. /etc/os-release;echo $ID$VERSION_ID) &&
        #     curl -s -L https://nvidia.github.io/nvidia-container-runtime/$distribution/nvidia-container-runtime.list | sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list; then
        #     sudo apt update
        #     sudo apt install -y nvidia-container-runtime
        # else
        #     scriptsLog 3 "Failed to add NVIDIA Docker APT repository."
        #     return
        # fi
    fi
    # 
    scriptsLog 0  "nvidia-docker2 installed"
}

# 
enable_bbr() {
    scriptsLog 1 "start enable BBR"
    # 
    if ! [[ $(cat /sys/module/tcp_bbr/parameters/available) == "1" ]]; then
        # 
        sudo modprobe tcp_bbr
        # 
        echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf
        # 
        echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
        # 
        sudo sysctl -p
    fi
    scriptsLog 0  "BBR enabled"
}

# 
node_exporter() {
     scriptsLog 1 "start configure node_exporter projects "
     createProject node_exporter
}

# 
gpu_exporter() {
     scriptsLog 1 "start configure gpu_exporter projects "
     createProject gpu_exporter
}

# 
accessApi() {
    local uri=$1        # 
    local project=$2    # 
    local data=$3       # 
    # 
    returnData=$(curl -s -H "Content-Type: application/json" -X POST -d     "${data[*]}" --insecure ${apiPostUrl}/${uri})
    # 
    if [ -z "$returnData" ]; then
        scriptsLog 3 "api request failed : ${apiPostUrl}/$uri"
        exit 3
    else
        # 
        if [ "$(echo ${returnData[*]} | $home/ipvRunner/Bin/jq -r '.returnCode')" == '200' ]; then
            scriptsLog 0 "$project node install SUCCESS"
        
        # 
        elif [ "$(echo ${returnData[*]} | $home/ipvRunner/Bin/jq -r '.returnCode')" == '203' ]; then
			scriptsLog 0 "$project node install SUCCESS"
		else
           		scriptsLog 3 "api returns error : ${returnData[*]}"
           		exit 3
		fi
    fi
}

# 
apiPost() {
    # 
    local overlayIp=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.ipvRunner.overlayIp')
    # 
    local appIds=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[].appId" | tr '\n' ',' |sed  '$s/.$//')
    # 
    local appNames=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[].appName" | tr '\n' ','| sed  '$s/.$//')
    # 
    local appParams=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r  ".apps[] | select(.appMode==1)|.appName" | tr '\n' ','| sed  '$s/.$//')
    # 
    local nodeType=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[].appMode" | tr '\n' ','| sed  '$s/.$//')
    # 
    local jsonData='{ 
            "nodeAddr":"'"$nodeAddr"'",
	        "nodeType":"'"$nodeType"'",
	        "nodeShare":"",
            "nodeName": "'"$nodeName"'" ,  
            "cpu": "'"$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c)"'" , 
            "gpu": "none" ,
            "geo": "none" , 
            "params" : "{\"overlayIp\":\"'"$overlayIp"'\",\"exIp\":\"'"$IP"'\",\"servicePort\":'"$port1"',\"speedTestPort\":'"$port2"'}", 
            "appIds": "'"$appIds"'", 
            "appNames": "'"$appNames"'",
            "appParams": "'"$appParams"'"}'
    
    scriptsLog 0 "api report information, please wait...."

    #
    accessApi user/nodeEnroll "calculate" "${jsonData[*]}" 
}

# 
main() {
# 
    CURL
    # 
    confInfo
    # 
    envInit
    # 
    cutLog
    # 

    # 
    NVIDIA
    # 
    enable_bbr
    #
    Docker
    # 
    nvidia_docker
    # 
    ipvRunner 
    # 
    writeConfig
    # 
    createProject nanoDownload
    # 
    nodeListen
    # 
	node_exporter
	#for gpu_exporter
	gpu_exporter
    # 
    #apiPost
}

#normalization parameter
ARGS=$(getopt -a -o h --long nodeAddr:,nodeName:,ipAddr:,port1:,port2:,home:,storage:,help -- "$@")
VALID_ARGS=$?

[ "$VALID_ARGS" != "0"  -o  -z  "$*" ] && { Help ;   exit; }

#Arrange parameter order
eval set -- "${ARGS}"   # 
while :;do
    case $1 in
        --nodeAddr)    nodeAddr=$2    ; shift ;;    # 
        --nodeName)    nodeName=$2    ; shift ;;    # 
        --ipAddr)      ipAddr=$2      ; shift ;;    # 
        --port1)       port1=$2       ; shift ;;    # 
        --port2)       port2=$2       ; shift ;;    # 
        --home)        home=$2        ; shift ;;    # 
        --storage)     storage=$2     ; shift ;;    # 
        -h|--help)     Help; exit 0   ; shift ;;    # 
        --)            shift; break   ; shift ;;    # 
    esac
    shift   # 
done

# 
main    

# 
scriptsLog 0 "Deployment complete"

# 
scriptsLog 1 "Please reconnect to the server or run [' source /etc/profile.d/ipvRunnerProfile.sh ']  to load the environment variables"

