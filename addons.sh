#!/bin/bash
set -e
RUN=false
DEFAULT_C=true
DEFAULT_PORT=5000
DEFAULT_CLUSTER_IP="10.254.0.50"
show_help () {
cat << USAGE
usage: $0 [ -r RUN-FLAG ] [ -o OMIT-COMMON-ADDONS ] [ -l DOCKER-LOCAL-REGISTRY ]
       [ -i LOCAL-REGISTRY-IP ] [ -p LOCAL-REGISTRY-PORT ]
       [ -c LOCAL-REGISTRY-CLUSTER-IP ] [ -q PORT-FOR-LOCAL-REGISTRY-CLUSTER-PORT ]

use to install addons for Kubernetes.

    -r : Specify the flag to run.
    -o : Specify the flag to omit the install common plug-ins.
         If not specified, install SkyDNS, Dashboard, Prometheus, 
         Nginx Ingress by default.
         If not installed the above addons, set the flag.

    Docker local registry:
    -l : Specify the flag to install a local registry of Docker.
         If not specified, not install by default. 
    -i : Specify the IP address of the host where the local registry resides.
    -p : Specify the port of the local registry.
         If not specified, use "${DEFAULT_PORT}" by default. 
    -c : Specify the cluster IP of the local registry.
         If not specified, use "${DEFAULT_CLUSTER_IP}" by default. 
    -q : Specify the port used by the cluster ip of the local registry.
         If not specified, use "${DEFAULT_PORT}" by default. 

This script should run on a Master node.
USAGE
exit 0
}
# Get Opts
while getopts "horli:p:c:q:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    r)  RUN=true
        ;;
    o)  OMIT=true
        ;;
    l)  LOCAL_INSTALL=true
        ;;
    i)  LOCAL_REGISTRY_IP=$OPTARG
        ;;
    p)  LOCAL_REGISTRY_PORT=$OPTARG
        ;;
    c)  LOCAL_REGISTRY_CLUSTER_IP=$OPTARG
        ;;
    q)  LOCAL_REGISTRY_CLUSTER_IP_PORT=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
chk_var () {
if [ -z "$2" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no input for \"$1\", try \"$0 -h\"."
  sleep 3
  exit 1
fi
}
[ -z "$*" ] && show_help
if ! $RUN; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - set the -r flag to run."
  exit 1
fi
[[ -n "$LOCAL_INSTALL" ]] && chk_var -i $LOCAL_REGISTRY_IP
[[ -n "$LOCAL_INSTALL" ]] && LOCAL_REGISTRY_PORT=${LOCAL_REGISTRY_PORT:-"${DEFAULT_PORT}"} 
[[ -n "$LOCAL_INSTALL" ]] && LOCAL_REGISTRY_CLUSTER_IP=${LOCAL_REGISTRY_CLUSTER_IP:-"${DEFAULT_CLUSTER_IP}"} 
[[ -n "$LOCAL_INSTALL" ]] && LOCAL_REGISTRY_CLUSTER_IP_PORT=${LOCAL_REGISTRY_CLUSTER_IP_PORT:-"${DEFAULT_PORT}"} 
STAGE=0
STAGE_FILE=stage.addons
if [ ! -f ./${STAGE_FILE} ]; then
  touch ./${STAGE_FILE}
  echo 0 > ./${STAGE_FILE}
fi
getScript () {
  TRY=10
  URL=$1
  SCRIPT=$2
  for i in $(seq -s " " 1 ${TRY}); do
    curl -s -o ./$SCRIPT $URL/$SCRIPT
    if cat ./$SCRIPT | grep "^404: Not Found"; then
      rm -f ./$SCRIPT
    else
      break
    fi
  done
  if [ -f "./$SCRIPT" ]; then
    chmod +x ./$SCRIPT
  else
    echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - downloading failed !!!" 
    echo " - $URL/$SCRIPT"
    echo " - Please check !!!"
    sleep 3
    exit 1
  fi
}
# restore from backup
BIN=restore-from-backup.sh
cat > ./$BIN<<"EOF"
#!/bin/bash
set -e
# 0 set env 
BAK_DIR=/var/k8s/bak
getBackup () {
  BAK_DIR=${1:-"/var/k8s/bak"}
  yes | cp -r $BAK_DIR/* ./
}
# 1 restore from backup
if [ -d "$BAK_DIR" ]; then
  getBackup $BAK_DIR
else
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - no $BAK_DIR found !!!"
  sleep 3
  exit 1
fi
exit 0
EOF
chmod +x ./$BIN
./$BIN
source ./info.env
WAIT=3

# 0 check
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $SCRIPTS/check-k8s-cluster.sh | /bin/bash 
  # check curl & 
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
  if [[ -n "$LOCAL_INSTALL" ]]; then
    curl -s $SCRIPTS/check-ansible.sh | /bin/bash
    BIN="get-through-hosts.sh"
    getScript $SCRIPTS $BIN
    ./${BIN} -i ${LOCAL_REGISTRY_IP}
  fi
fi

# 1 CoreDNS
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  if [[ -z "${OMIT}" ]]; then
    curl -s $STAGES/deploy-coredns.sh | /bin/bash 
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 Dashboard
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  if [[ -z "${OMIT}" ]]; then
    curl -s $STAGES/deploy-dashborad.sh | /bin/bash 
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 Prometheus 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  if [[ -z "${OMIT}" ]]; then
    curl -s $STAGES/deploy-prometheus.sh | /bin/bash 
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 nginx ingress
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  if [[ -z "${OMIT}" ]]; then
    curl -s $STAGES/deploy-nginx-ingress.sh | /bin/bash 
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 docker local registry 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  if [[ -n "$LOCAL_INSTALL" ]]; then
    BIN=deploy-docker-local-registry.sh
    getScript $STAGES $BIN
    ./$BIN -i ${LOCAL_REGISTRY_IP} -p ${LOCAL_REGISTRY_PORT} -c ${LOCAL_REGISTRY_CLUSTER_IP} -q ${LOCAL_REGISTRY_CLUSTER_IP_PORT}
  fi
  echo $STAGE > ./${STAGE_FILE}
fi
