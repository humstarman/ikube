SHELL=/bin/bash
NET=192.168.100
MASTER=192.168.100.161,192.168.100.162,192.168.100.163
NODE=192.168.100.164,192.168.100.165
BASIC_ARG=-m ${MASTER} -n ${NODE}
SCKEY=SCU31080T5747dd558f09b5ecab28adf0b081d80b5b7cdf2331e11,SCU31117T4ea33e3f348ef4cb6ca4fd88c7ef7e805b7e0839105ab
MSG_ARG=-k ${SCKEY} 

all: init 

init: run

#run:export ARG=-a vip -v 192.168.100.241 -c calico -x ipvs -k v1.11.1
run:export ARG=-p 9ol.8ik, -a vip -i 192.168.100.240 -c calico -v v1.11.1 -x ipvs
run:export ARGS=${BASIC_ARG} ${MSG_ARG} ${ARG}
run:
	@./init.sh ${ARGS}

approve:
	@./approve-pem.sh

test:
	@kubectl get nodes

key:
	@echo ${MSG_ARG}

join:
	@./join-node.sh -r node -i ${NEW}
