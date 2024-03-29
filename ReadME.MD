# ngpu-installation
=======
Install/uninstall script for NGPU client

##Usage
### node requirements
- Hardware
GPU: RTX GPU 3080 and above; professional GPU T4，A10 and above
CPU >= 12 Cores , 
Memory >= 16GB，
Storage >= 500GB。

- Software
OS: ubuntu >= 20.04 LTS x64
Docker: >= 20.10, installation script can update 
NVIDIA driver: >= 525.125，Cuda 12.0, installation script can update
nvidia-docker2: >= 2.13

- Network:
Bandwidth: up/down >= 50Mbps，
public IP is best, or port mapping：TCP 8070-8080，TCP 7777.  

### installation 
1. Clone the repository: git clone https://github.com/AINNGPU-Community/ngpu-install-script.git
2. Make sure all *.sh executable: chmod +x -R *.sh
3. Run installation script:
There are two kinds of nodes in NGPU, one for common computing node, which runs computing task, like AI, rendering. The other is for network measuring, which doesn't need GPU.
- Computing node:  
```
   ./install_mcNode.sh \
   --nodeAddr 43eac68ff697c07ec40bd52e5ed6209c7db8ac7e  \
   --nodeName test \
   --ipAddr 192.168.1.106 \
   --home /home/demo \
   --storage 500 

--nodeAddr：node address from new-account in ngpu-cli
--home：local path for client
--ip：binding ip, don't use 127.0.0.1. Please use ip in one network card.
--storage：committed storage size，in GB. All the data and model files are located under $home/ipvRunner/ipvTemp. 

```
- Measure node: 
```
   ./install_measure.sh \
   --nodeAddr 43eac68ff697c07ec40bd52e5ed6209c7db8ac7e  \
   --nodeName test \
   --ipAddr 192.168.1.106 \
   --home /home/demo \
   --storage 500 \

--nodeAddr：node address from new-account in ngpu-cli
--home：local path for client
--ip：binding ip, don't use 127.0.0.1. Please use ip in one network card.
--storage：committed storage size，in GB. All the data and model files are located under $home/ipvRunner/ipvTemp. 

```
### uninstallation
In the same directory as install script, there is one uninstall script.
- Computing node: ./uninstall_mcNode.sh
- Measure node: ./uinstall_measure.sh

### Tested OS
Ubuntu 18.04, 20.04, 22.04, and centos7.9


