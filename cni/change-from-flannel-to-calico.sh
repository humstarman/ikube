#!/bin/bash

set -e

START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.f2c
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
  - This script is change CNI from Flannel to Calico.
  ===
  - This script MUST run on a Kubernets MASTER !!!
  ===
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

# 0 check environment 
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $TOOLS/check-k8s-cluster.sh | /bin/bash
  curl -s $TOOLS/restore-info-from-backup.sh | /bin/bash
  curl -s $TOOLS/check-needed-files.sh | /bin/bash
  curl -s $TOOLS/check-ansible.sh | /bin/bash
  curl -s $TOOLS/mk-ansible-available.sh | /bin/bash
fi

# 1 clear flannel 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/clear-flannel.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 deploy calico 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/deploy-calico.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 replace node componenets 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/replace-node-components.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 replace node componenets 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/deploy-cli-tool.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $TOOLS/clearance.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# ending
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - CNI changed from Flannel to Calico"
FILE=approve-pem.sh
if [ ! -f "$FILE" ]; then
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
fi
echo " - For a little while, use the script ./$FILE to approve kubelet certificate, if needed."
echo " - use 'kubectl get csr' to check the register, if needed."
sleep $WAIT
exit 0
