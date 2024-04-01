#!/bin/bash
# 2022-05-18
# 2022-11-20
# 2023-09-05
# version 0.3

# 安装指令举例： ./install_measure.sh --nodeAddr 0xf9cfaa04f5c56577944cb1651ce77c07ede74c01 --nodeName AAA-node --ipAddr 192.168.15.3 --home /home/ainngpu --storage 100

# 配置获取地址,包含节点地址参数
configUrl='http://ecotoolstest.ainngpu.io:8443/ipvConfigML/ipvConfig?nodeAddr='

# 安装包下载地址   
softUrl='http://ecotools.ainngpu.io:81'

# API接口地址
apiPostUrl='https://gslb.ainngpu.cn'

# 安装程序所需空间,单位GB  
deployerSpace=2 #unit GB

# 默认端口
port1=7777
port2=11111

# 端口范围
portS=($port1 $port2 8070 8071 8080 8081 8082 8084 8096 8097 8090 8500-8999 8100-8499 8890)

# 禁止脚本运行中断
#trap   ""  INT QUIT  TSTP

#help information
Help(){	
    # 打印脚本使用帮助
    echo -e "\nUsage: sh $0 [OPTION]"
    # 打印可选参数标题
    echo -e "Options:"
    # 打印参数标记 
    echo -e "[OPTION]"
    # 打印nodeAddr参数帮助
	echo -e "[ --nodeAddr ]   node address from registration page       e.g. a3c46471cd252903f784dbdf0ff426f0d2abed47 "
    # 打印nodeName参数帮助
	echo -e "[ --nodeName ]   node name                                 e.g. zhangsan-node"
    # 打印ipAddr参数帮助
	echo -e "[ --ipAddr   ]   local ip to public area                   e.g. 192.168.1.100 "
    # 打印home参数帮助
	echo -e "[ --home     ]   Installation Path                         e.g. /home/user/ainngpu/"
    # 打印storage参数帮助
	echo -e "[ --storage  ]   Commitment disk size default unit GB      e.g. 500"
    # 打印帮助参数标记
	echo -e "[ -h|--help  ]   display this help and exit \n"
}

#print log
scriptsLog() {
    # 获取状态码
    statusCode=$1
    # 获取日志信息
    logInfo=$2
    # 状态码为0,打印成功日志  
    if [ $statusCode == 0 ]; then
        echo -e "[\033[32m SUCCESS \033[0m]:\t${logInfo[*]}"
    # 状态码为1,打印普通信息日志
    elif [ $statusCode == 1 ]; then
        echo -e "[   INFO  ]:\t${logInfo[*]}"
    # 状态码为2,打印警告日志
    elif [ $statusCode == 2 ]; then
        echo -e "[\033[33m   WARN  \033[0m]:\t${logInfo[*]}"
    # 状态码为3,打印错误日志  
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

# 功能:检查端口是否可用
ChkPort(){
    # 获取端口参数
    port=$1
    # 判断端口是否为整数
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        # 检查端口是否已被使用
        if [ ! -z "$(ss -ntlp | grep -w :$port)" ]; then
            scriptsLog 3 "[port:$port]  is already used in the system : $port"
        # 检查端口范围是否在5000-65535之间  
        elif [  $port -le 5000 -o  "$port" -ge 65535 ];then
            scriptsLog 3 "[port:$port] range of ports is 5000 - 65535 : $port"
        fi
    # 端口不是整数
    else
           scriptsLog 3 "[port:$port] port only of integer" 
    fi
}

# 功能:检查环境参数
EnvChk() {
    # 设置返回标志
    tag=0
    
    # 输出检查参数提示
    scriptsLog 1 "Start checking the parameters you entered..."
    
    # 检查是否为root用户
    [ $(id -u) != "0" ] && scriptsLog 3 "Please run the script as root user" 
    
    # 检查curl是否可用
    if ! which curl >/dev/null; then
        scriptsLog 3 "This script requires \"curl\" utility to work correctly"
    fi

    # 检查nodeAddr是否为空
    if [ -z "$nodeAddr" ];then
        scriptsLog 3 "[nodeAddr] parameter cannot be empty"
    fi

    # 检查api状态码
    local status=$(curl -I -m 30  -o /dev/null -s -w %{http_code} ${configUrl}${nodeAddr})
    if [ "$status" == 200 ]; then
        jsonConfig=$(curl -s ${configUrl}${nodeAddr})
    else
        scriptsLog 3 "cannot install measure node client on this computer. please contact society."
        Help
        exit
    fi
      
    # 检查本地时间和服务器时间差
    apiTime=$(echo ${jsonConfig} | egrep -o 'time\":[0-9]+' | egrep -o '[0-9]+')
    timeDiff=$(expr $(date '+%s') - $apiTime)
    if [ $timeDiff -gt 60 -o $timeDiff -lt -60 ]; then
        scriptsLog 3 "Please sync server time, node local time: $(date "+%Y-%m-%d %H:%M:%S"), ${timeDiff} seconds difference from IpvRunner server"
    fi

    # 检查ipAddr是否为空
    [ -z "$ipAddr" ] &&  scriptsLog 3 "[ipAddr] cannot be empty"
      
    # 检查nodeName是否为空
    [ -z "$nodeName" ] && scriptsLog 3 "[nodename] cannot be empty"

    # 检查端口是否重复
    [ $port1 == $port2 ] && scriptsLog 3 "[port1:$port1] and [port2:$port2] are repeated"

    # 遍历检查端口
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
   
    # 检查home参数
    if [ -z "$home" ];then
        scriptsLog 3 "[home] The installation path cannot be empty"
	Help
	exit
    fi

    # 检查home目录是否存在
    if [ ! -d $home ]; then 
        mkdir -p $home
	scriptsLog 2 "[home] directory does not exist, it has been created for you"
    fi

    # 检查存储空间
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
    
    # 参数检查成功
    if [ $tag == 0 ]; then 
        scriptsLog 0 "Parameter check succeeded"
    else
        scriptsLog 3 "The parameter check failed, please check it and try again"
        Help
        exit
    fi
}

# 功能:获取公网IP
getIp() {
    # 使用命令替换，获取本机的IP地址
    # ip addr：列出所有网络接口的信息
    # egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'：使用正则表达式提取出IP地址
    # egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\."：排除私有IP地址、回环地址等特定地址
    # head -n 1：获取第一个匹配到的IP地址，并将其赋值给变量 "IP"
    IP=$(ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1)

    # 检查变量 "IP" 是否为空，如果为空，则尝试从 "ipinfo.io" 获取公共IP地址
    # -z ${IP}：检查变量 "IP" 是否为空
    # &&：如果前一个命令成功执行（即变量 "IP" 为空），则执行下一个命令
    # wget -qO- -t1 -T2 ipinfo.io/ip：使用 wget 命令获取 "ipinfo.io/ip" 的内容，并将其赋值给变量 "IP"
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )

    # 再次检查变量 "IP" 是否为空，如果为空，则尝试从 "cip.cc" 获取公共IP地址
    # -z ${IP}：检查变量 "IP" 是否为空
    # &&：如果前一个命令成功执行（即变量 "IP" 为空），则执行下一个命令
    # curl -s cip.cc：使用 curl 命令获取 "cip.cc" 的内容
    # grep IP：查找包含 "IP" 的行
    # awk '{print $3}'：使用 awk 提取第三列的内容，即IP地址
    [ -z ${IP} ] && IP=$( curl -s cip.cc | grep IP | awk '{print $3}' )
}

# 功能:确认用户信息
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

# 功能:下载文件
downloadFile() {
   
    local downloadUrl=$1    # 将函数的第一个参数（下载URL）存储到本地变量 "downloadUrl"
    local savePath=$2       # 将函数的第二个参数（保存路径）存储到本地变量 "savePath"
    local fileName=$3       # 将函数的第三个参数（文件名）存储到本地变量 "fileName"
    local progress=$4       # 将函数的第四个参数（进度）存储到本地变量 "progress"
    local fileType=${fileName#*.}   # 使用字符串截取操作获取文件扩展名并存储到本地变量 "fileType"

    #[ ${fileType} == 'tar.gz' -o ${fileType} == 'tar' ] && return 0
    
    # 根据 "progress" 是否为空来设置 "options" 变量
    [ -z "${progress}" ] && options='-s' || options='-L --progress-bar'

    # 如果 "/tmp/${fileName}" 文件存在，将其重命名为 "/tmp/${fileName}.bak"
    [ -f "/tmp/${fileName}" ] && mv /tmp/${fileName} /tmp/${fileName}.bak
	
    # 使用 curl 获取下载链接的 HTTP 状态码并存储到 "status" 变量
    local status=$(curl -I -m 30 -o /dev/null -s -w %{http_code} $downloadUrl)

    # 如果状态码不等于 200
    if [ "$status" != 200 ]; then
        scriptsLog 3 "downloading: http status code not 200 "$downloadUrl" \n $(curl -s $downloadUrl)"
        Help    # 调用 Help 函数
        exit    # 退出脚本
    fi
	
    # 使用 curl 下载文件到 /tmp/${fileName}
    if ! curl ${options[*]} "$downloadUrl" -o /tmp/${fileName}; then
        scriptsLog 3 "Can't download ${projectName} file to /tmp/"
        exit 3
    fi

    # 如果保存路径不存在，则创建目录
    [ ! -d "$savePath" ] && mkdir -p $savePath

    # 如果文件类型是 tar.gz 或 tar
    if [ ${fileType} == 'tar.gz' -o ${fileType} == 'tar' ];then

        # 解压文件到指定目录
        if ! tar xf /tmp/${fileName} -C ${savePath};then
            scriptsLog 3 "Can't unpack /tmp/${fileName} to ${savePath} directory"
        fi
    else
        # 使用 \cp 命令复制文件到指定目录
        \cp /tmp/${fileName} $savePath
    fi

    # 删除临时文件
    rm -f /tmp/${fileName}
}

# 功能:创建系统服务
createProject() {
    local name=$1   # 将函数的第一个参数（项目名称）存储到本地变量 "name"
    local After=$2  # 将函数的第二个参数（依赖关系列表）存储到本地变量 "After"
    # 创建项目的 systemd 服务
    scriptsLog 1 "create $name systemd service"
    if [ ! -f "$home/ipvRunner/Bin/${name}.sh" ]; then  # 如果启动脚本文件不存在
        # 记录错误日志，指示找不到启动脚本文件
        scriptsLog 3 "create $name no startup script"
        # 给出联系系统管理员的建议
        scriptsLog 2 "[$name]  Please contact your system administrator"
        # 退出脚本，返回错误码 2
        exit 2
    fi
    # 生成 systemd 服务文件内容并保存到临时文件
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
    # 如果项目名称是 'cloudRender'
    if [ $name == 'cloudRender' ];then
        # 向服务文件添加额外的配置项
        sed -i "8i PIDFile\=$home/ipvRunner/Tools/cloudRender/cloudrender-server/logs/server-0.pid" /tmp/${name}.service 
        sed -i "8i Environment=PM2_HOME=/root/.pm2" /tmp/${name}.service 
    fi

    # 将生成的服务文件移动到 /etc/systemd/system/ 目录下
    mv -bf /tmp/${name}.service /etc/systemd/system/${name}.service

    # 重新加载 systemd 配置
    systemctl daemon-reload
	
    # 检查服务是否已经在运行
    if $home/ipvRunner/Bin/${name}.sh status ; then
        scriptsLog 2 "Stop the already running process $name"
	$home/ipvRunner/Bin/${name}.sh stop # 停止已经在运行的进程
    fi

    # 记录日志，指示正在配置系统启动
    scriptsLog 1 "Configure $name system  startup"

    # 启用 systemd 服务，禁止输出
    systemctl enable ${name}.service >/dev/null 2>&1

    # 启动 systemd 服务，禁止输出
    systemctl start ${name}.service >/dev/null 2>&1

    # 检查服务的状态，如果启动失败，则记录错误日志
    if ! systemctl status ${name}.service >/dev/null; then
        scriptsLog 3 "Startup failed [$name]"
        scriptsLog 2 "[$name]  Please contact your system administrator"
        exit 2
    else
        scriptsLog 0 "startup SUCCESS [$name]"
    fi
}

# 功能:初始化环境
envInit(){
    # 下载项目文件
    scriptsLog 1 "download project file"
    downloadFile $softUrl/tools/ipolloML/ipvRunner.tar.gz "$home"  "ipvRunner.tar.gz" "progressTrue"

    # 安装 jq 用于处理 JSON 数据
    downloadFile $softUrl/tools/jq "$home/ipvRunner/Bin/"  "jq"
    chmod +x $home/ipvRunner/Bin/jq
    
    # 创建临时配置文件
    >/tmp/ipvRunnerProfile.sh

    # 下载模块
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
    
    # 添加 TestTools 项目路径到系统 PATH
    for i in $(ls $home/ipvRunner/TestTools); do
        scriptsLog 1 "add  $i modules path to system PATH"
        echo "#apps ${i}" >>/tmp/ipvRunnerProfile.sh
        echo "export PATH=${home}/ipvRunner/TestTools/$i:\$PATH" >>/tmp/ipvRunnerProfile.sh
        echo >>/tmp/ipvRunnerProfile.sh
    done
    
    # 添加 Tools 项目路径到系统 PATH
    for i in  $( ls $home/ipvRunner/Tools/ ); do
        scriptsLog 1 "add  $i modules path to system PATH"
        echo "#apps ${i}" >>/tmp/ipvRunnerProfile.sh
        echo "export PATH=${home}/ipvRunner/Tools/$i:\$PATH" >>/tmp/ipvRunnerProfile.sh
        echo  >>/tmp/ipvRunnerProfile.sh
    done

    # 添加 nodejs 项目路径到系统 PATH
    scriptsLog 1 "add  nodejs  modules path to system PATH"
    echo "#nodejs" >>/tmp/ipvRunnerProfile.sh
    echo "export NODE_HOME=${home}/ipvRunner/Tools/node" >>/tmp/ipvRunnerProfile.sh
    echo "export PATH=\$NODE_HOME/bin:\$PATH" >>/tmp/ipvRunnerProfile.sh
    
    # 如果日志目录不存在，创建它
    [ ! -d "$home/ipvRunner/log" ] && mkdir -p $home/ipvRunner/log
    
    # 配置权限和环境变量
    chmod 755 -R $home/ipvRunner
    chmod +x /tmp/ipvRunnerProfile.sh
    
    # 添加项目脚本到 /etc/profile.d/ipvRunner.sh
    scriptsLog 1 "Adding project script to /etc/profile.d/ipvRunnerProfile.sh"

    # 复制配置文件到 /etc/profile.d/
    \cp  /tmp/ipvRunnerProfile.sh /etc/profile.d/ipvRunnerProfile.sh    

    # 启用新的配置文件
    source /etc/profile.d/ipvRunnerProfile.sh
}

# 功能:写config.json文件
writeConfig() {

    # 修改config.json文件
    echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.bridge' | sed -r "s/xxxx/$port1/g" >$home/ipvRunner/config.json

}

# 功能:安装IpvRunner节点管理程序
ipvRunner() {
 
    scriptsLog 1 "start configure IpvRunner"

    # 获取CPU信息并存储到变量 "cpu"
    cpu=$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c)

    # 设置nodeType为333
    local nodeType=333

    # 使用 jq 处理 JSON 配置文件并生成 ipvrunner.json
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

    # 创建 nodeListen 项目的 systemd 服务
	createProject nodeListen service

    # 如果 "~/.config/autostart/" 目录不存在，创建它
	[ ! -d "~/.config/autostart/" ] && mkdir -p  ~/.config/autostart/

    # 创建一个 autostart 桌面文件，用于在用户登录时自动启动 ipvRunner
    cat > ~/.config/autostart/ipvRunner.desktop <<EOL
[Desktop Entry]

Type=Application

Exec=$home/ipvRunner/Bin/ipvRunner.sh start
EOL
	# 启动 ipvRunner 服务
	$home/ipvRunner/Bin/ipvRunner.sh start
	
}

# 功能:创建日志切割定时任务
cutLog() {
    scriptsLog 1 "Create cron cut log"
    crontab -l | grep -v  cut_log > conf ; echo "01 00 * * *  $home/ipvRunner/Bin/cut_log.sh" >> conf && crontab conf && rm -f conf
}

# 功能:安装 Docker
Docker() {
    scriptsLog 1 "start install Docker"
    # 检查是否已安装 Docker
    if ! command -v docker &> /dev/null; then
        # 如果未安装 Docker，则进行安装
        # 更新系统包列表
        sudo apt update
        # 安装必要的依赖以允许apt通过HTTPS使用存储库
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        # 添加Docker官方的GPG密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        # 添加Docker存储库
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        # 安装Docker引擎
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        # 启动Docker服务并设置开机自启动
        sudo systemctl start docker
        sudo systemctl enable docker
        # 添加当前用户到docker组，以避免使用sudo运行docker命令
        sudo usermod -aG docker $USER
        # 输出Docker版本信息
        docker --version
    fi
    # 完成安装
    scriptsLog 0  "Docker installed"
}

# 启用BBR
enable_bbr() {
    scriptsLog 1 "start enable BBR"
    # 检查/sys/module/tcp_bbr/parameters/available是否包含"1"
    if ! [[ $(cat /sys/module/tcp_bbr/parameters/available) == "1" ]]; then
        # 添加BBR内核模块
        sudo modprobe tcp_bbr
        # 将BBR设置为默认的拥塞控制算法
        echo "tcp_bbr" | sudo tee /etc/modules-load.d/bbr.conf
        # 更新sysctl配置以启用BBR
        echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
        # 应用sysctl配置
        sudo sysctl -p
    fi
    scriptsLog 0  "BBR enabled"
}

# 功能:安装 curl
CURL() {
    scriptsLog 1 "start install curl"
    # 检查是否已经安装了curl
    if ! command -v curl &> /dev/null; then
        sudo apt update
        sudo apt install -y curl
    fi
    # 完成安装
    scriptsLog 0  "curl installed"
}

# 功能:安装节点监控exporter
node_exporter() {
     scriptsLog 1 "start configure node_exporter projects "
     createProject node_exporter
}

# 功能:安装节点ipollo监听服务
ipollo_exporter() {
    scriptsLog 1 "start configure ipollo_exporter "
	if [ -f "$home/ipvRunner/nodeAddress" ]; then 
		rm -f "$home/ipvRunner/nodeAddress"
	fi
	echo ${nodeAddr} > $home/ipvRunner/nodeAddress
    # 创建 ipollo_exporter 项目的 systemd 服务
    createProject ipollo_exporter
}

# 功能:API注册节点
accessApi() {
    local uri=$1        # 将第一个参数赋值给本地变量 "uri"
    local project=$2    # 将第二个参数赋值给本地变量 "project"
    local data=$3       # 将第三个参数赋值给本地变量 "data"

    # 使用curl命令向API发送POST请求，并将返回结果存储在本地变量 "returnData" 中
    returnData=$(curl -s -H "Content-Type: application/json" -X POST -d     "${data[*]}" --insecure ${apiPostUrl}/${uri})
    
    # 检查是否返回数据为空
    if [ -z "$returnData" ]; then
        scriptsLog 3 "api request failed : ${apiPostUrl}/$uri"
        exit 3
    else
        # 检查API返回的数据中的 "returnCode" 字段值是否为 '200'
        if [ "$(echo ${returnData[*]} | $home/ipvRunner/Bin/jq -r '.returnCode')" == '200' ]; then
            scriptsLog 0 "$project node install SUCCESS"
        
        # 检查API返回的数据中的 "returnCode" 字段值是否为 '203'
        elif [ "$(echo ${returnData[*]} | $home/ipvRunner/Bin/jq -r '.returnCode')" == '203' ]; then
			scriptsLog 0 "$project node install SUCCESS"
		else
           		scriptsLog 3 "api returns error : ${returnData[*]}"
           		exit 3
		fi
        fi
}

# 功能:上报节点信息
apiPost() {
    # 从 jsonConfig 中提取 overlayIp，并存储在本地变量 "overlayIp" 中
    local overlayIp=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.ipvRunner.overlayIp')

    # 从 jsonConfig 中提取多个 app 的 appId，以逗号分隔，并存储在本地变量 "appIds" 中
    local appIds=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[].appId" | tr '\n' ',' |sed  '$s/.$//')

    # 从 jsonConfig 中提取多个 app 的 appName，以逗号分隔，并存储在本地变量 "appNames" 中
    local appNames=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[].appName" | tr '\n' ','| sed  '$s/.$//')

    # 从 jsonConfig 中提取 appMode 为 1 的 app 的 appName，以逗号分隔，并存储在本地变量 "appParams" 中
    local appParams=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r  ".apps[] | select(.appMode==1)|.appName" | tr '\n' ','| sed  '$s/.$//')

    # 从 jsonConfig 中提取多个 app 的 appMode，以逗号分隔，并存储在本地变量 "nodeType" 中
    local nodeType=$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r ".apps[].appMode" | tr '\n' ','| sed  '$s/.$//')
    
    # 构建 JSON 数据字符串 "jsonData"
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
            
    # 提取 JSON 数据中的 "params" 字段
    params=$(echo -e ${jsonData[*]} | $home/ipvRunner/Bin/jq -r '.params' | sed 's/\"/\\"/g')
    
    # 构建包含 "nodeAddr" 的 JSON 数据
    local jsonData='{"nodeAddr": "'"$nodeAddr"'","orgName": "none","nodeName": "'"$nodeName"'","params": "'"${params[*]}"'"}'

    # 调用 accessApi 函数，发送 JSON 数据到 "user/measureEnroll" API
    accessApi  user/measureEnroll "measure" "${jsonData[*]}" 
}

# 主程序入口
main() {
    # 调用CURL 函数，安装curl
    CURL
    # 调用名为 "confInfo" 的函数，用于获取配置信息
    confInfo
    # 调用名为 "envInit" 的函数，用于初始化环境
    envInit
    # 调用名为 "cutLog" 的函数，可能用于分割日志文件
    cutLog
    # 调用名为 "ipvRunner" 的函数，可能是用于运行IPvRunner相关任务
    ipvRunner 
    # 调用名为 "Docker" 的函数
    Docker
    # 调用启用BBR函数
    enable_bbr
    # 调用名为 "writeConfig" 的函数，将config文件写入
    writeConfig
    # 调用名为 "node_exporter" 的函数，可能是用于配置和启动node_exporter
	node_exporter
    # 调用名为 "apiPost" 的函数, enroll for this node. but it is no use now. ipvRunner enrolls at start. 
    #apiPost
}

#normalization parameter
ARGS=$(getopt -a -o h --long nodeAddr:,nodeName:,ipAddr:,port1:,port2:,home:,storage:,help -- "$@")
VALID_ARGS=$?

[ "$VALID_ARGS" != "0"  -o  -z  "$*" ] && { Help ;   exit; }

#Arrange parameter order
eval set -- "${ARGS}"   # 将规范化后的参数重新设置为命令行参数
while :;do
    case $1 in
        --nodeAddr)    nodeAddr=$2    ; shift ;;    # 处理 "--nodeAddr" 参数，将其值存储在 "nodeAddr" 变量中，并移动参数指针
        --nodeName)    nodeName=$2    ; shift ;;    # 处理 "--nodeName" 参数，将其值存储在 "nodeName" 变量中，并移动参数指针
        --ipAddr)      ipAddr=$2      ; shift ;;    # 处理 "--ipAddr" 参数，将其值存储在 "ipAddr" 变量中，并移动参数指针
        --port1)       port1=$2       ; shift ;;    # 处理 "--port1" 参数，将其值存储在 "port1" 变量中，并移动参数指针
        --port2)       port2=$2       ; shift ;;    # 处理 "--port2" 参数，将其值存储在 "port2" 变量中，并移动参数指针
        --home)        home=$2        ; shift ;;    # 处理 "--home" 参数，将其值存储在 "home" 变量中，并移动参数指针
        --storage)     storage=$2     ; shift ;;    # 处理 "--storage" 参数，将其值存储在 "storage" 变量中，并移动参数指针
        -h|--help)     Help; exit 0   ; shift ;;    # 处理 "-h" 或 "--help" 参数，调用 "Help" 函数并退出脚本
        --)            shift; break   ; shift ;;    # 处理 "--" 参数，表示后面的参数不再解析，移动参数指针并退出循环
    esac
    shift   # 移动参数指针以处理下一个参数
done

# 调用名为 "main" 的函数，开始执行脚本的主要逻辑
main    

# 记录部署完成的日志消息
scriptsLog 0 "Deployment complete"

# 提示用户重新连接服务器或加载环境变量的日志消息
scriptsLog 1 "Please reconnect to the server or run [' source /etc/profile.d/ipvRunnerProfile.sh ']  to load the environment variables"
