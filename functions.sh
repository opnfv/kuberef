#!/bin/bash

# Clean up

function clean_up() {
	sudo virsh destroy $VM_NAME
	sudo virsh undefine $VM_NAME
	sudo rm -rf /var/lib/libvirt/images/$VM_NAME
}

# Create jumphost VM

function create_jump() {
	./create_vm.sh $VM_NAME
	sleep 30
}

# Get jumphost VM IP

function get_vm_ip() {
	export VM_IP=$(sudo virsh domifaddr ${VM_NAME} | sed 3q | sed '$!d' |awk '{print $4}' | cut -d/ -f1)
	echo "VM IP is ${VM_IP}"
}

# Setup PXE network

function setup_PXE_network() {
	VM_IP=$(sudo virsh domifaddr ${VM_NAME} | sed 3q | sed '$!d' |awk '{print $4}' | cut -d/ -f1)
# SSH to jumphost
	ssh -o StrictHostKeyChecking=no -tT $USERNAME@$VM_IP << EOF
# configure PXE network (Adapt as per your pxe network setup)
	sudo ifconfig $PXE_IF up
	sudo ifconfig $PXE_IF $PXE_IF_IP netmask $NETMASK
        sudo ifconfig $PXE_IF hw ether $PXE_IF_MAC
EOF
}

# Copy files needed by Infra engine & BMRA in the jumphost VM

function copy_files_jump() {
	scp -r -o StrictHostKeyChecking=no $CURRENTPATH/{hw_config/,sw_config/,setup_network.sh,httpboot/deployment_image.qcow2} $USERNAME@$VM_IP:$PROJECT_ROOT
}

# Host Provisioning

function provision_hosts() {
	ssh -tT $USERNAME@$VM_IP << EOF
	if [ ! -d "${PROJECT_ROOT}/engine" ]; then
	ssh-keygen -t rsa -N "" -f $PROJECT_ROOT/.ssh/id_rsa
	git clone https://gerrit.nordix.org/infra/engine.git
	cp $PROJECT_ROOT/hw_config/* $PROJECT_ROOT/engine/engine
	sudo mkdir /httpboot && sudo cp -r $PROJECT_ROOT/deployment_image.qcow2 /httpboot #will be removed when centos image path will be added in infra-engine
	fi
	cd $PROJECT_ROOT/engine/engine && git checkout 863cf75 && ./deploy.sh -o centos7 -p file:///$PROJECT_ROOT/engine/engine/pdf.yaml -i file:///$PROJECT_ROOT/engine/engine/idf.yaml -l provision
EOF
}

# Setup networking on provisioned hosts (Adapt setup_network.sh according to your network setup) 

function setup_network() {
# SSH to jumphost
	ssh -tT $USERNAME@$VM_IP << EOF
	ssh -o StrictHostKeyChecking=no root@$MASTER_IP 'bash -s' <  ${PROJECT_ROOT}/setup_network.sh
	ssh -o StrictHostKeyChecking=no root@$WORKER_IP 'bash -s' <  ${PROJECT_ROOT}/setup_network.sh
EOF
}

# k8s Provisioning (currently BMRA)

function provision_k8s() {
# SSH to jumphost
	ssh -tT $USERNAME@$VM_IP << EOF
# Install BMRA
	if [ ! -d "${PROJECT_ROOT}/container-experience-kits" ]; then
		sudo apt install -y docker.io
		sleep 5
		git clone https://github.com/intel/container-experience-kits.git
		cd ${PROJECT_ROOT}/container-experience-kits 
		git checkout v1.4.1
		git submodule update --init
                cp -r examples/group_vars examples/host_vars .
                cp ${PROJECT_ROOT}/sw_config/inventory.ini ${PROJECT_ROOT}/container-experience-kits/
                cp ${PROJECT_ROOT}/sw_config/all.yml ${PROJECT_ROOT}/container-experience-kits/group_vars/
                cp ${PROJECT_ROOT}/sw_config/node1.yml ${PROJECT_ROOT}/container-experience-kits/host_vars/
		fi
	sudo service docker start
	sudo docker run --rm -v ${PROJECT_ROOT}/container-experience-kits:/bmra -v ~/.ssh/:/root/.ssh/ rihabbanday/bmra-install:centos ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/cluster.yml
EOF
}
