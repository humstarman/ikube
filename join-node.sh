#!/bin/bash
set -e
show_help () {
cat << USAGE
usage: $0 [ -r ROLE ] [ -i IP(s) ]

use to add node(s) to Kubernetes.

    -r : Specify the role of the new node(s) to add, for instance: "master" or "node". 
    -i : Specify the IP address(es) of new node(s). If multiple, set the nodes in term of csv, 
         as 'ip-1,ip-2,ip-3'.

This script should run on a Master (to be) node.
USAGE
exit 0
}
# Get Opts
while getopts "hr:i:" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    r)  ROLE=$OPTARG # 参数存在$OPTARG中
        ;;
    i)  IPS=$OPTARG
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
chk_var -r $ROLE
chk_var -i $IPS
STAGE=0
STAGE_FILE=stage.join
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
