#!/bin/bash

set -e

# set env
START=$(date +%s)
WAIT=3
STAGE=0
STAGE_FILE=stage.master
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
  - This script is for adding master(s) to Kubernetes cluster.
  ===
  - This script MUST run on a Kubernets MASTER !!!
  ===
  - The info about new master(s) should be offered.
  - As an instance:
  - generate a file named new.csv,
  - new node IPs are in terms of CSV, as {IP_1},{IP_2},{IP_3}.
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
  FILE=new.csv.tmpl
  if [ ! -f "$FILE" ]; then
    touch $FILE
    echo "1.1.1.1,1.1.1.2,1.1.1.3" > $FILE
    sed -i s/" "/","/g $FILE
  fi
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

# 0 check environment 
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $TOOLS/check-k8s-cluster.sh | /bin/bash
  curl -s $TOOLS/restore-info-from-backup.sh | /bin/bash 
  curl -s $TOOLS/check-needed-files.sh | /bin/bash 
  curl -s $TOOLS/check-new-one.sh | /bin/bash 
  curl -s $TOOLS/detect-conflict.sh | /bin/bash
  curl -s $TOOLS/check-ansible.sh | /bin/bash 
  curl -s $TOOLS/mk-ansible-available.sh | /bin/bash
  ## 1 shutdown selinux
  curl -s -o ./shutdown-selinux.sh $TOOLS/shutdown-selinux.sh
  ansible new -m script -a ./shutdown-selinux.sh
  ## 2 stop firewall
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - stop firewall."
  curl -s -o ./stop-firewall.sh $TOOLS/stop-firewall.sh
  ansible new -m script -a ./stop-firewall.sh
  ## 3 mkdirs
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - prepare directories."
  curl -s $MAIN/batch-mkdir.sh | /bin/bash
fi

# 1 set env 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cluster-environment-variables.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 cp CA pem
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-ca-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 deploy etcd 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-etcd-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 prepare kubernetes master componenets
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-kubernetes-master-components.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 cp kubectl 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/cp-kubectl.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 6 deploy flanneld 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/deploy-flanneld.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 7 deploy master 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/deploy-master.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 8 deploy node 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $MAIN/deploy-node.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 9 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $TOOLS/clearance.sh | /bin/bash
  echo $STAGE > ./${STAGE_FILE}
fi

# ending
MASTER=$(sed s/","/" "/g ./master.csv)
N_MASTER=$(echo $MASTER | wc -w)
if [ ! -f ./node.csv ]; then
  N_NODE=0
else
  NODE=$(sed s/","/" "/g ./node.csv)
  N_NODE=$(echo $NODE | wc -w)
  [ -z "$N_NODE" ] && N_NODE=0
fi 
TOTAL=$[${N_MASTER}+${N_NODE}]
END=$(date +%s)
ELAPSED=$[$END-$START]
MINUTE=$[$ELAPSED/60]
NEW=$(sed s/","/" "/g ./new.csv)
N_NEW=$(echo $NEW | wc -w)
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - summary: "
if [[ "1" == "$N_NEW" ]]; then
  echo " - add only one new node into Kubernetes cluster elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
else
  echo " - add $N_NEW new nodes into Kubernetes cluster elapsed: $ELAPSED sec, approximately $MINUTE ~ $[$MINUTE+1] min."
fi
echo " - Previous Kubernetes paltform: "
echo " - Total nodes: $TOTAL"
echo " - With masters: $N_MASTER"
echo " --- "
TOTAL=$[${TOTAL}+${N_NEW}]
echo " - Current Kubernetes paltform: "
echo " - Total nodes: $TOTAL"
echo " - With masters: $N_MASTER"
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
echo " - For a little while, use the script ./$FILE to approve kubelet certificate."
echo " - use 'kubectl get csr' to check the register."
## re-set env
curl -s $TOOLS/re-set-env-after-master.sh | /bin/bash
## make backup
THIS_DIR=$(cd "$(dirname "$0")";pwd)
curl -s $TOOLS/update-ansible-hosts.sh | /bin/bash
curl -s $TOOLS/mk-backup.sh | /bin/bash
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - backup important info from $THIS_DIR to /var/k8s/bak."
sleep $WAIT
exit 0
