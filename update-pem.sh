#!/bin/bash
set -e
DEFAULT_YEAR=1
RUN=false
show_help () {
cat << USAGE
usage: $0 [ -r RUN-FLAG ] [ -y YEAR ]
use to update permissons used in Kubernetes.

    -y : Specify the period of validity in term of year.
         If not specified, use "$DEFAULT_YEAR" by default.
    -r : Specify the flag to run. 

This script should run on a Master node.
USAGE
exit 0
}
# Get Opts
while getopts "hy:r" opt; do # 选项后面的冒号表示该选项需要参数
    case "$opt" in
    h)  show_help
        ;;
    r)  RUN=true 
        ;;
    y)  YEAR=$OPTARG
        ;;
    ?)  # 当有不认识的选项的时候arg为?
        echo "unkonw argument"
        exit 1
        ;;
    esac
done
[ -z "$*" ] && show_help
if ! $RUN; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - set the -r flag to run."
  exit 1 
fi
YEAR=${YEAR:-"${DEFAULT_YEAR}"}
STAGE=0
STAGE_FILE=stage.update
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
    if cat ./$SCRIPT | grep "404: Not Found"; then
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

# 0 clear expired permission & check cfssl tool
if [[ "$(cat ./${STAGE_FILE})" == "0" ]]; then
  curl -s $SCRIPTS/check-k8s-cluster.sh | /bin/bash 
  curl -s $SCRIPTS/check-needed-files.sh | /bin/bash
  curl -s $SCRIPTS/check-ansible.sh | /bin/bash 
  curl -s $SCRIPTS/mk-ansible-available.sh | /bin/bash 
  getScript $STAGES clear-expired-pem.sh
  ansible ${ANSIBLE_GROUP} -m script -a ./clear-expired-pem.sh
  curl -s $SCRIPTS/check-cfssl.sh | /bin/bash 
fi

# 1 CA
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  getScript $STAGES update-ca-pem.sh
  ./update-ca-pem.sh -y $YEAR -g ${ANSIBLE_GROUP}
  echo $STAGE > ./${STAGE_FILE}
fi

# 2 etcd 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $STAGES/update-etcd-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 3 kubectl 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $STAGES/update-kubectl-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 4 flanneld 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  if [[ "flannel" == "${CNI}" ]]; then
    curl -s $STAGES/update-flanneld-pem.sh | /bin/bash 
  fi
  echo $STAGE > ./${STAGE_FILE}
fi

# 5 kubernetes 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $STAGES/update-kubernetes-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 6 kubelet 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $STAGES/update-kubelet-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 7 kube-proxy 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $STAGES/update-kube-proxy-pem.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 8 restart services 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  curl -s $STAGES/restart-svc.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# 9 clearance 
STAGE=$[${STAGE}+1]
if [[ "$(cat ./${STAGE_FILE})" < "$STAGE" ]]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - Kubernetes permmisson has been updated. "
  curl -s $SCRIPTS/clearance.sh | /bin/bash 
  echo $STAGE > ./${STAGE_FILE}
fi

# ending
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - As updating permissons, re-approving certificate is needed."
echo " - sleep $WAIT sec, then apporve."
FILE=approve-pem.sh
if [ ! -f "$FILE" ]; then
  cat > $FILE <<"EOF"
#!/bin/bash
CSRS=$(kubectl get csr | grep Pending | awk -F ' ' '{print $1}')
if [ -n "$CSRS" ]; then
  for CSR in $CSRS; do
    kubectl certificate approve $CSR
  done
fi
EOF
  chmod +x $FILE
fi
for i in $(seq -s " " 1 $WAIT); do
  sleep $WAIT
  ./${FILE}
done
echo " - now, use 'kubectl get node' to check the status."
kubectl get node
echo " - if there is/are NotReady node/nodes, use 'kubectl get csr' to check the register status."
echo " - use ./$FILE to approve certificate."
exit 0
