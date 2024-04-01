#!/bin/bash
# 2022-05-18
# 2022-11-20
# 2023-09-07
# 2023-10-08 dos2unix
#version 0.3

# 安装指令举例： ./install_mcNode.sh --nodeAddr 0xf9cfaa04f5c56577944cb1651ce77c07ede74c01 --nodeName AAA-node --ipAddr 192.168.15.3 --home /home/ipolloverse --storage 100

# 配置获取地址,包含节点地址参数
configUrl='http://ecotoolstest.ainngpu.io:8443/ipvConfigML/ipvConfig?nodeAddr='

# 安装包下载地址   
softUrl='http://ecotools.ainngpu.io:81'

# API接口地址
apiPostUrl='https://gslb.ipolloverse.cn'

# 获取新的nodeAddr地址
apiNewAccountUrl="https://gslb.ipolloverse.cn/user/newAccount"

# 获取Keystore文件
apiKeystoreUrl="https://gslb.ipolloverse.cn/user/getKeystore?fileName="

# 节点注册地址
apiRegisterUrl="https://gslb.ipolloverse.cn/user/nodeRegister"

# 获取系统当前语言设置
system_language="$LANG"

# 是否需要进行节点注册
registerNode=false

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
	echo -e "[ nodeAddr ]   node address from registration page       e.g. 0xa3c46471cd252903f784dbdf0ff426f0d2abed47 "
    # 打印nodeName参数帮助
	echo -e "[ nodeName ]   node name                                 e.g. zhangsan-node"
    # 打印walletAddr参数帮助
	echo -e "[ walletAddr ]   wallet address                          e.g. 0xa3c46471cd252903f784dbdf0ff426f0d2abed47 "
    # 打印orgName参数帮助
	echo -e "[ orgName ]   Name of the organization to which the node belongs  e.g. EBC Mining Pool "
    # 打印ipAddr参数帮助
	echo -e "[ ipAddr   ]   local ip to public area                   e.g. 192.168.1.100 "
    #echo -e "[ --port1    ]   ipvrunner listen port1                    e.g. 7777"
	#echo -e "[ --port2    ]   ipvrunner listen port2                    e.g. 11111"
    # 打印home参数帮助
	echo -e "[ home     ]   Installation Path                         e.g. /home/user/ipolloverse/"
    # 打印storage参数帮助
	echo -e "[ storage  ]   Commitment disk size default unit GB      e.g. 500"
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
        scriptsLog 3 "[nodeAddr]  parameter cannot be empty"
    fi

    # 检查api状态码
    local status=$(curl -I -m 30  -o /dev/null -s -w %{http_code} ${configUrl}${nodeAddr})
    if [ "$status" == 200 ]; then
        jsonConfig=$(curl -s ${configUrl}${nodeAddr})
    else
        scriptsLog 3 "http status code not 200 "${configUrl}${nodeAddr}" \n $(curl -s ${configUrl}${nodeAddr})"
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

    # 检查port1和port2的端口是否是int
    re='^[0-9]+$'
    if ! [[ $port1 =~ $re ]] ; then
        scriptsLog 3 "[port1] port1 is not an integer"
    fi
    if ! [[ $port2 =~ $re ]] ; then
        scriptsLog 3 "[port2] port2 is not an integer"
    fi

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
    echo -e "Your walletAddr        : \033[32m ${walletAddr} \033[0m"
    echo -e "Your orgName        : \033[32m ${orgName} \033[0m"
    echo -e "Your local ipAddr    : \033[32m ${ipAddr} \033[0m"
    echo -e "Your public ipAddr   : \033[32m ${IP} \033[0m"
    #echo -e "Your server port1    : \033[32m $port1 \033[0m"
    #echo -e "Your server port2    : \033[32m $port2 \033[0m"
    echo -e "Your install path    : \033[32m ${home} \033[0m"
    echo -e "Your storage size    : \033[32m ${storage} \033[0m"
    echo
    # printf "Are you sure install ? (y/n)"
    # printf "\n"
    # read -p "(Default: n):" -e answer
    # [ -z ${answer} ] && answer="n"
    # if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        scriptsLog 1 "Install service please wait...."
    # else
        # exit 0
    # fi
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
        scriptsLog 1 "startup SUCCESS [$name]"
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
    # 设置为普通mc节点
    nodeType=0
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
    crontab -l | grep -v  cut_ipolloverse_log > conf ; echo "01 00 * * *  $home/ipvRunner/Bin/cut_ipolloverse_log.sh" >> conf && crontab conf && rm -f conf
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

# 功能:安装节点监听服务
nodeListen() {
    scriptsLog 1 "start configure nodeListen "
    # 创建 nodeListen 项目的 systemd 服务
    createProject nodeListen
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

# 功能:安装nebula组网
nebula() {
    scriptsLog 1 "start configure nebula "
    downloadFile "$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.network.hostCrt')" "$home/ipvRunner/Tools/nebula/" "host.crt" 
    downloadFile "$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.network.hostKey')" "$home/ipvRunner/Tools/nebula/" "host.key" 
    downloadFile "$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.network.nodeCrt')" "$home/ipvRunner/Tools/nebula/" "node.crt" 
    downloadFile "$(echo ${jsonConfig[*]} | $home/ipvRunner/Bin/jq -r '.network.nodeYaml')" "$home/ipvRunner/Tools/nebula/" "node.yaml" 
    createProject nebula 
}

# 功能:安装 NVIDIA 驱动和 CUDA
NVIDIA() {
    scriptsLog 1 "start install NVIDIA && CUDA"
    # 检查是否已安装 NVIDIA 驱动
    if ! nvidia-smi &> /dev/null; then
        # 如果未安装 NVIDIA 驱动，则进行安装
        # 添加 NVIDIA 驱动 PPA 存储库
        sudo add-apt-repository ppa:graphics-drivers/ppa
        # 更新包列表
        sudo apt-get update
        # 安装 NVIDIA 525 版本驱动
        sudo apt-get install -y nvidia-driver-525
        # 安装 CUDA12版本
        sudo apt-get install -y cuda-12.0
    fi
    scriptsLog 0 "NVIDIA && CUDA installed"
}

# 功能:安装 gpu_exporter, not called yet, just use binary from website. 
#GPU() {
#    scriptsLog 1 "start install gpu_exporter"
#    # 检查是否已安装 gpu_exporter
#    if ! command -v nvidia_gpu_prometheus_exporter &> /dev/null; then
#        # 如果未安装 gpu_exporter，则进行安装
#        # 更新包列表
#        sudo apt-get update
#        # 安装 Go 编译器和 Git
#        sudo apt-get install -y golang-go git
#        # 下载并编译 gpu_exporter
#        git clone https://github.com/mindprince/nvidia_gpu_prometheus_exporter.git
#        cd nvidia_gpu_prometheus_exporter
#        go build
#        # 启动 gpu_exporter
#        createProject nvidia_gpu_prometheus_exporter
#    fi
#    scriptsLog 0 "gpu_exporter installed"
#}

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

# 功能:安装 Docker
Docker() {
    scriptsLog 1 "start install Docker"
    docker_version="5:20.10.21~3-0~ubuntu-focal"
    # 检查是否已安装 Docker
    if ! command -v docker &> /dev/null; then
        # 如果未安装 Docker，则进行安装
        # 更新系统包列表
        sudo apt update
        if [ -f "/usr/share/keyrings/docker-archive-keyring.gpg" ]; then
                rm -f "/usr/share/keyrings/docker-archive-keyring.gpg"
        fi

        # 安装必要的依赖以允许apt通过HTTPS使用存储库
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        # 添加Docker官方的GPG密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        # 添加Docker存储库
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        # 安装Docker引擎
        sudo apt update
        sudo apt install -y docker-ce=$docker_version docker-ce-cli=$docker_version containerd.io
        # 启动Docker服务并设置开机自启动
	sudo systemctl unmask docker.service
        sudo systemctl start docker
        sudo systemctl enable docker
        # 添加当前用户到docker组，以避免使用sudo运行docker命令
        sudo usermod -aG docker $USER
        # 输出Docker版本信息
        docker --version
        # 创建目录
        local dockerPath=$home/ipvRunner/ipvTemp/dockerStorage
        sudo mkdir -p $dockerPath
        # 修改docker的存储目录为指定的目录
        echo '{"data-root": "'"$dockerPath"'"}' | sudo tee /etc/docker/daemon.json > /dev/null

    else
		dockerPath
    fi
    sudo systemctl restart docker
    # 完成安装
    scriptsLog 0  "Docker installed"
}

# 功能:安装 nvidia-docker2的2.13版本
nvidia_docker() {
    scriptsLog 1 "start install nvidia-docker"

    # 检查是否已经安装nvidia-docker2的2.13版本
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

        # 添加 NVIDIA Docker 的 APT 存储库
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
    # 完成安装
    scriptsLog 0  "nvidia-docker2 installed"
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

# 功能:安装节点监控exporter
node_exporter() {
     scriptsLog 1 "start configure node_exporter projects "
     createProject node_exporter
}

# 功能:安装节点GPU监控exporter
gpu_exporter() {
     scriptsLog 1 "start configure gpu_exporter projects "
     createProject gpu_exporter
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
    
    scriptsLog 0 "api report information, please wait...."

    # 调用 accessApi 函数，发送 JSON 数据到 "user/nodeEnroll" API
    accessApi user/nodeEnroll "calculate" "${jsonData[*]}" 
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
    # 调用名为 "nebula" 的函数，执行与Nebula相关的操作
    # nebula
    # 调用名为 "NVIDIA" 的函数，执行与NVIDIA相关的操作
    NVIDIA
    # 调用enable_bbr函数，来启动BBR
    enable_bbr
    # 调用名为 "Docker" 的函数，执行与Docker相关的操作
    Docker
    # 调用nvidia-docker函数，安装nvidia-docker2的2.13版本
    nvidia_docker
    # 调用名为 "ipvRunner" 的函数，可能是用于运行IPvRunner相关任务
    ipvRunner 
    # 调用名为 "writeConfig" 的函数，将config文件写入
    writeConfig
    # 调用名为 "createProject" 的函数，创建一个名为 "nanoDownload" 的项目
    createProject nanoDownload
    # 调用名为 "nodeListen" 的函数，用于监听节点的活动
    nodeListen
    # 调用名为 "node_exporter" 的函数，可能是用于配置和启动node_exporter
	node_exporter
	#for gpu_exporter
	gpu_exporter
	#for ipollo_exporter
	ipollo_exporter
    # 调用名为 "apiPost" 的函数，enroll for this node. but it is no use now. ipvRunner enrolls at start
    #apiPost
}


# # 检测环境
# checkEnv() {
#     # 检测Nvidia驱动是否安装
#     checkNvidia
#     # 检测Docker环境是否安装
#     checkDocker
#     # 检测BBR是否打开
#     checkBBR
#     # 检测IPVRuner是否安装
#     checkIPVRuner
#     # 检测node_exporter是否安装
#     checkNodeExporter
#     # 检测gpu_exporter是否安装
#     checkGPUExporter
# }

##### 提示用户输入相关的信息

# 安装指令举例： ./install_mcNode.sh --nodeAddr 0xf9cfaa04f5c56577944cb1651ce77c07ede74c01 --nodeName AAA-node --ipAddr 192.168.15.3 --home /home/ipolloverse --storage 100

###0：先安装jq可以对http返回的内容进行json解析
sudo apt update
sudo apt install jq

###1：请求用户输入节点地址 
    read -p "Please enter your node address (by default, the system will create a node address for you): " nodeAddr
    if [ -z "$nodeAddr" ];then
        # 地址为空，需要给用户创建一个新的地址:
        response_file=$(mktemp)
        curl -s -o "$response_file" "$apiNewAccountUrl"
        # 检查curl是否成功发起请求
        if [ $? -ne 0 ]; then
            scriptsLog 3 "http request new account failed"
            exit 1
        fi

        # 解析JSON响应并提取所需的数据
        # 以下示例假设JSON响应中有一个名为 "key" 的字段
        key_value=$(jq -r '.fileName' "$response_file")
        # 提取里面的nodeAddr
        nodeAddr="${key_value%%_*}"

        # 打印新的节点地址
        scriptsLog 0 "The newly acquired node address is: $nodeAddr"

        # 删除临时文件
        rm -f "$response_file"

        # 下载Keystore文件
        curl -OJL "$apiKeystoreUrl$nodeAddr"
        # 检查curl是否成功下载文件
        if [ $? -eq 0 ]; then
            # 获取当前目录中的文件名
            downloaded_file=$(ls -t | head -1)
            filePath="$PWD/$downloaded_file"
            scriptsLog 0 "The keystore file has been downloaded to the current directory: $filePath"
        else
            scriptsLog 3 "Failed to download the Keystore file"
        fi

        # 设置需要进行节点注册
        registerNode=true
    fi

###2：请求用户输入节点名称 
    read -p "Please enter your node name: " nodeName
    if [ -z "$nodeName" ];then
        # 创建节点名称
        nodeName=$(date +"iPollo_TestMc%Y_%m_%d_%H:%M:%S")

        # 打印新的节点名称
        scriptsLog 0 "Creating a new node name for you: $nodeName"
    fi


###3：请求用户进行节点与钱包地址绑定
    while true; do
        read -p "Please bind your wallet address(Must be filled in): " walletAddr

        # 检查用户是否提供了有效的输入（这里假设输入不能为空）
        if [ -n "$walletAddr" ]; then
            scriptsLog 0 "The wallet address you have bound (Must be filled in): $walletAddr"
            break
        else
            scriptsLog 3 "You need to enter the wallet address to bind the node"
        fi
    done


###4：请求用户输入组织名称
    while true; do
        read -p "Please enter your organization's name: " orgName

        # 检查用户是否提供了有效的输入（这里假设输入不能为空）
        if [ -n "$orgName" ]; then
            scriptsLog 0 "The organization name you entered is:: $orgName"
            break
        else
            scriptsLog 3 "You need to enter the organization to which your node belongs"
        fi
    done


###5：请求用户输入节点Ip 
    while true; do
        read -p "Please enter your node Ip address(Must be filled in): " ipAddr
        
        # 检查用户是否提供了有效的输入（这里假设输入不能为空）
        if [ -n "$ipAddr" ]; then
            scriptsLog 0 "The IP address of the node you entered is: $ipAddr"
            break
        else
            scriptsLog 3 "You have not provided your IP address. Please enter it again"
        fi
    done


###6：请求用户输入安装的根目录
    while true; do
        read -p "Please enter your installation root directory: " home
        
        # 检查用户是否提供了有效的输入（这里假设输入不能为空）
        if [ -n "$home" ]; then
            scriptsLog 0 "The installation root directory you entered is: $home"
            break
        else
            scriptsLog 3 "You have not entered your installation root directory. Please enter it again"
        fi
    done


###7：请求用户输入提供的存储空间大小
    while true; do
        read -p "Please enter the size of the hard disk you are providing（In gigabytes GB, default is 100GB）: " storage
        
        # 检查用户是否提供了有效的输入（这里假设输入不能为空）
        if [ -n "$storage" ]; then
            scriptsLog 0 "The size of the hard disk you entered is: $storage"
            break
        else
            storage=100
            scriptsLog 0 "The size of the hard disk you entered is: $storage"
            break
        fi
    done


###8：发起一个注册节点的请求
    if [ "$registerNode" = true ]; then
        # 定义要发送的JSON数据
        body="{\"nodeAddr\": \"$nodeAddr\", \"orgName\": \"$orgName\", \"walletAccount\": \"$walletAddr\"}"
        # 发起一个Post请求
        response=$(curl -s -X POST -H "Content-Type: application/json" -d "$body" "$apiRegisterUrl")
        # 检查curl是否成功发起请求
        if [ $? -eq 0 ]; then
            scriptsLog 0 "Your node has been successfully registered: $nodeAddr"
        else
            scriptsLog 3 "Your node registration has failed: $nodeAddr"
        fi
    fi


# 调用名为 "main" 的函数，开始执行脚本的主要逻辑
main    

# 记录部署完成的日志消息
scriptsLog 0 "Deployment complete"

# 对安装的环境进行检测
# scriptsLog 1 "Check Current Env"
# checkEnv

# 提示用户重新连接服务器或加载环境变量的日志消息
scriptsLog 1 "Please reconnect to the server or run [' source /etc/profile.d/ipvRunnerProfile.sh ']  to load the environment variables"

