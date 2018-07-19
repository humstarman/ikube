#!/bin/bash
set -e
if false; then
B=$1
if [ -z "$B" ]; then
  echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [ERROR] - input the branch wanted to be replaced !!!"
  sleep 3
  exit 1
fi
fi
THIS_BRANCH=$(git branch | grep "*")
THIS_BRANCH=${THIS_BRANCH##*" "}
THIS_FILE=$0
THIS_FILE=${THIS_FILE##*/}
TARGET="BRANCH="
find ./ -type f | grep -v $THIS_FILE |xargs sed -i "/$TARGET/ c ${TARGET}${THIS_BRANCH}"
echo "$(date -d today +'%Y-%m-%d %H:%M:%S') - [INFO] - branch change to ${THIS_BRANCH}"
exit 0
