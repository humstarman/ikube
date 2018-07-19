#!/bin/bash

set -e

show_help () {
cat << USAGE
usage: $0 [ -m MASTER(S) ] [ -n NODE(S) ] [ -v VIRTUAL-IP ] [ -p PASSORD ]
use to deploy Kubernetes.

    -m : Specify the IP address(es) of Master node(s). If multiple, set the images in term of csv, 
         as 'master-ip-1,master-ip-2,master-ip-3'.
    -n : Specify the IP address(es) of Node node(s). If multiple, set the images in term of csv, 
         as 'node-ip-1,node-ip-2,node-ip-3'.
         If not specified, no nodes would be installed.
    -v : Specify the virtual IP address. 
    -p : Specify the uniform password of hosts. 

This script should run on a Master (to be) node.
USAGE
exit 0
}

# Get Opts
while getopts "hm:v:n:p:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    m)  MASTER=$OPTARG # 参数存在$OPTARG中
        ;;
    v)  VIP=$OPTARG
        ;;
    n)  NODE=$OPTARG
        ;;
    p)  PASSWD=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
[ -z "$*" ] && show_help

chk_var () {
if [ -z "$2" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no input for \"$1\", try \"$0 -h\"."
  sleep 3
  exit 1
fi
}
chk_var -m $MASTER
chk_var -v $VIP
chk_var -p $PASSWD

START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.init
if [ ! -f ./${STAGE_FILE} ]; then
  INIT=0
  touch ./${STAGE_FILE}
  echo 0 > ./${STAGE_FILE} 
else
  INIT=1
fi
getScript () {
  URL=$1
  SCRIPT=$2
  curl -s -o ./$SCRIPT $URL/$SCRIPT
  chmod +x ./$SCRIPT
}
PROJECT="test-demo"
BRANCH=v1.11_vip_calico
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/${BRANCH}
TOOLS=${URL}/tools
#TOOLS=https://raw.githubusercontent.com/humstarman/${PROJECT}-static/master/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}
###
#if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
###
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - checking environment ... "
# check curl & 
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  if [ ! -x "$(command -v curl)" ]; then
    if [ -x "$(command -v yum)" ]; then
      yum makecache fast
      yum install -y curl
    fi
    if [ -x "$(command -v apt-get)" ]; then
      apt-get update
      apt-get install -y curl
    fi
  fi
fi
curl -s -O $MAIN/version
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && curl -s $TOOLS/check-ansible.sh | /bin/bash
echo $MASTER > ./master.csv
MASTER=$(echo $MASTER | tr "," " ")
#echo $MASTER
N_MASTER=$(echo $MASTER | wc -w)
#echo $N_MASTER
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_MASTER masters: $(cat ./master.csv)."
if [ -z "$NODE" ]; then
  NODE_EXISTENCE=false
else
  NODE_EXISTENCE=true
  echo $NODE > ./node.csv
fi
if $NODE_EXISTENCE; then
  NODE=$(echo $NODE | tr "," " ")
  #echo ${NODE}
  N_NODE=$(echo $NODE | wc -w)
  #echo $N_NODE
  [[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $N_NODE nodes: $(cat ./node.csv)."
else
  [[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - no node to install."
fi
echo $VIP > ./vip.info
[[ "$(cat ./${STAGE_FILE})" == "0" ]] && echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - virtual IP: $(cat ./vip.info)."
echo $PASSWD > ./passwd.log
# mk env file
FILE=info.env
if [ ! -f "$FILE" ]; then
  cat > $FILE << EOF
export MASTER="$MASTER"
export N_MASTER=$N_MASTER
export NODE_EXISTENCE=$NODE_EXISTENCE
export NODE="$NODE"
export N_NODE=$N_NODE
export URL=$URL
export VIP=$VIP
EOF
fi
###
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
###
  curl -s $TOOLS/mk-ansible-available.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - connectivity checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - environment checked."
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare to install."
  ## 1 stop selinux
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - shutdown Selinux."
  curl -s -o ./shutdown-selinux.sh $TOOLS/shutdown-selinux.sh
  ansible all -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  curl -s -o ./stop-firewall.sh $TOOLS/stop-firewall.sh
  ansible all -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  curl -s $MAIN/batch-mkdir.sh | /bin/bash
###
fi
###

# 1 environment variables
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  ## 1 download scripts
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - config cluster environment variables ... "
  #getScript $URL cluster-environment-variables.sh
  curl -s $MAIN/cluster-environment-variables.sh | /bin/bash
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - cluster environment variables configured. "
###
echo $STAGE > ./${STAGE_FILE}
fi
###

# 2 generate CA pem
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/generate-ca-pem.sh | /bin/bash
#getScript $URL generate-ca-pem.sh 
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 3 deploy ha etcd cluster
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/deploy-etcd.sh | /bin/bash
#getScript $URL deploy-etcd.sh
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 4 prepare kubernetes 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
### at first, install Kubernetes
  curl -s $MAIN/install-k8s.sh | /bin/bash
#getScript $URL install-k8s.sh
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 5 deploy kubectl
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
### then deploy kubectl
  curl -s $MAIN/deploy-kubectl.sh | /bin/bash
#getScript $URL deploy-kubectl.sh
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 6 deploy flanneld
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  #curl -s $MAIN/deploy-flanneld.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 7 deploy master 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  curl -s $MAIN/deploy-master.sh | /bin/bash
  curl -s $MAIN/deploy-ha.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 8 deploy node
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
#getScript $URL deploy-node.sh
  curl -s $MAIN/deploy-node.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 9 deploy calico 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
#getScript $URL deploy-node.sh
FILE=approve-pem.sh
  cat > $FILE << EOF
#!/bin/bash
CSRS=\$(kubectl get csr | grep Pending | awk -F ' ' '{print \$1}')
if [ -n "\$CSRS" ]; then
  for CSR in \$CSRS; do
    kubectl certificate approve \$CSR
  done
fi
EOF
  chmod +x $FILE
  sleep $WAIT 
  ./${FILE}
  curl -s $MAIN/deploy-calico.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# 10 clearance 
STAGE=$[${STAGE}+1]
###
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
###
  [ -f "./node.csv" ] || touch node.csv
  curl -s $TOOLS/clearance.sh | /bin/bash
###
  echo $STAGE > ./${STAGE_FILE}
fi
###

# ending
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w)
if [ ! -f ./node.csv ]; then
  N_NODE=0
else
  NODE=$(cat ./node.csv | tr "," " ")
  N_NODE=$(echo $NODE | wc -w)
  [ -z "$N_NODE" ] && N_NODE=0
fi 
TOTAL=$[${N_MASTER}+${N_NODE}]
END=$(date +%s)
ELAPSED=$[$END-$START]
MINUTE=$[$ELAPSED/60]
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - summary: "
echo " - Kubernetes installation elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
echo " - Kubernetes paltform: "
echo " - Total nodes: $TOTAL"
echo " - With masters: $N_MASTER"
## make backup
THIS_DIR=$(cd "$(dirname "$0")";pwd)
curl -s $TOOLS/mk-backup.sh | /bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - backup important info from $THIS_DIR to /var/k8s/bak."
sleep $WAIT 
exit 0
