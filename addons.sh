#!/bin/bash

set -e

START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.addons
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
show_help () {
cat << USAGE
usage: $0
  - This script is for the installation of:
  - CoreDNS
  - Dashboard
  - Nginx Ingress
  -
USAGE
if [[ "0" == "$INIT" ]]; then
  cat << USAGE
  ---
  ---
  ---
  If you run the script for the first time,
  the help document shown by default.
  Re-run the script to function.
  ---
USAGE
fi
sleep $WAIT
exit 0
}
if [[ "0" == "$INIT" ]]; then
  show_help
fi  
# Get Opts
while getopts "h" opt; do 
    case "$opt" in
    h)  show_help
        ;;
    ?)
        echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - unkonw argument."
        exit 1
        ;;
    esac
done
PROJECT="test-demo"
# https://raw.githubusercontent.com/humstarman/test-demo-addons/master/coredns/coredns.yaml
<<<<<<< HEAD
BRANCH=master
=======
BRANCH=master
>>>>>>> v1.11_flannel
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/${BRANCH}
TOOLS=${URL}/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}

if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $TOOLS/check-k8s-cluster.sh | /bin/bash 
fi

# 1 CoreDNS
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="coredns"
  kubectl create -f $MAIN/${COMPONENT}/coredns.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 Dashboard
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="dashboard"
  COMPONENT_URL=$MAIN/$COMPONENT
  kubectl create -f $COMPONENT_URL/rbac.yaml
  kubectl create -f $COMPONENT_URL/configmap.yaml
  kubectl create -f $COMPONENT_URL/secret.yaml
  kubectl create -f $COMPONENT_URL/service.yaml
  kubectl create -f $COMPONENT_URL/controller.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 Prometheus 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="prometheus"
  COMPONENT_URL=$MAIN/$COMPONENT
  kubectl create -f $COMPONENT_URL/manifests-all.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 nginx ingress
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  COMPONENT="ingress"
  COMPONENT_URL=$MAIN/$COMPONENT
  kubectl create -f $COMPONENT_URL/namespace.yaml
  kubectl create -f $COMPONENT_URL/rbac.yaml
  kubectl create -f $COMPONENT_URL/default-backend.yaml
  kubectl create -f $COMPONENT_URL/configmap.yaml
  kubectl create -f $COMPONENT_URL/tcp-services-configmap.yaml
  kubectl create -f $COMPONENT_URL/udp-services-configmap.yaml
  kubectl create -f $COMPONENT_URL/service.yaml
  kubectl create -f $COMPONENT_URL/with-rbac.yaml
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - $COMPONENT deployed."
  echo $STAGE > ./${STAGE_FILE}
fi
