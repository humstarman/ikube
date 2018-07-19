#!/bin/bash

set -e

START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.clear
if [ ! -f ./${STAGE_FILE} ]; then
  INIT=0
  touch ./${STAGE_FILE}
  TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
  echo $TOKEN > ./${STAGE_FILE} 
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
[ -z "$TOKEN" ] && TOKEN=$(cat ./${STAGE_FILE})
cat << USAGE
usage: $0 [ -t TOKEN ]
  - Dangerous script !!!
  - This script is to used to clear Kubenetes in this cluster !!!
  - Dangerous script !!!
  - Dangerous script !!!
  -
  - use this token:
  - $TOKEN
  - as the input of this script, and MUST on Kubernetes MASTER to function.
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
while getopts "ht:" opt; do 
    case "$opt" in
    h)  show_help
        ;;
    t)  INPUT_TOKEN=$OPTARG
        ;;
    ?)
        echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - unkonw argument."
        exit 1
        ;;
    esac
done
if [[ "$INPUT_TOKEN" != "$(cat ./${STAGE_FILE})" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - token mismatched !!!"
  sleep $WAIT
  exit 1
fi
PROJECT="test-demo"
<<<<<<< HEAD
BRANCH=v1.11_vip_calico
=======
BRANCH=v1.11_vip_calico
>>>>>>> v1.11_flannel
URL=https://raw.githubusercontent.com/humstarman/${PROJECT}-impl/${BRANCH}
TOOLS=${URL}/tools
THIS_FILE=$0
PREFIX=$THIS_FILE
PREFIX=${PREFIX##*/}
PREFIX=${PREFIX%.*}
MAIN=${URL}/${PREFIX}

# 0 set env 
curl -s $TOOLS/restore-info-from-backup.sh | /bin/bash
curl -s $TOOLS/check-needed-files.sh | /bin/bash
curl -s $TOOLS/check-ansible.sh | /bin/bash 

# 1 clearance 
COMPONENT="node"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - clear $COMPONENT ... "
getScript $MAIN clear-${COMPONENT}.sh
ansible all -m script -a ./clear-${COMPONENT}.sh
COMPONENTS="master etcd"
for COMPONENT in $COMPONENTS; do
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - clear $COMPONENT ... "
  getScript $MAIN clear-${COMPONENT}.sh
  ansible master -m script -a ./clear-${COMPONENT}.sh
done

# ending
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [WARN] - Kubernetes cluster cleared."
exit 0
