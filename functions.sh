#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Clean up
clean_up() {
    if sudo virsh list --all | grep "${VM_NAME}.*running" ; then
        sudo virsh destroy "$VM_NAME"
    fi
    if sudo virsh list --all | grep "${VM_NAME}" ; then
        sudo virsh undefine "$VM_NAME"
    fi
    sudo rm -rf "/var/lib/libvirt/images/$VM_NAME"
    sleep 5
}

# Create jumphost VM
create_jump() {
    ./create_vm.sh "$VM_NAME"
    sleep 30
}

# Get jumphost VM IP
get_vm_ip() {
    sudo virsh domifaddr "$VM_NAME" | awk 'FNR == 3 {gsub(/\/.*/, ""); print $4}'
}

# Setup PXE network
setup_PXE_network() {
    # shellcheck disable=SC2087
    ssh -o StrictHostKeyChecking=no -tT "$USERNAME"@"$(get_vm_ip)" << EOF
sudo ifconfig $PXE_IF up
sudo ifconfig $PXE_IF $PXE_IF_IP netmask $NETMASK
sudo ifconfig $PXE_IF hw ether $PXE_IF_MAC
EOF
}

# Copy files needed by Infra engine & BMRA in the jumphost VM
copy_files_jump() {
    scp -r -o StrictHostKeyChecking=no \
    "$CURRENTPATH"/{hw_config/"$VENDOR"/,sw_config/"$INSTALLER"/} \
    "$USERNAME@$(get_vm_ip):$PROJECT_ROOT"
}

# Host Provisioning
provision_hosts() {
    # shellcheck disable=SC2087
    ssh -tT "$USERNAME"@"$(get_vm_ip)" << EOF
# Install and run cloud-infra
if [ ! -d "${PROJECT_ROOT}/engine" ]; then
    ssh-keygen -t rsa -N "" -f ${PROJECT_ROOT}/.ssh/id_rsa
    git clone https://gerrit.nordix.org/infra/engine.git
    cp $PROJECT_ROOT/$VENDOR/{pdf.yaml,idf.yaml} \
    ${PROJECT_ROOT}/engine/engine
# NOTE: will be removed when centos image path will be added in infra-engine
sudo mkdir /httpboot
# sudo cp -r ${PROJECT_ROOT}/deployment_image.qcow2 /httpboot
fi
cd ${PROJECT_ROOT}/engine/engine
./deploy.sh -s ironic -d centos7 \
-p file:///${PROJECT_ROOT}/engine/engine/pdf.yaml \
-i file:///${PROJECT_ROOT}/engine/engine/idf.yaml
EOF
}

# Setup networking on provisioned hosts (Adapt setup_network.sh according to your network setup)
setup_network() {
    # shellcheck disable=SC2087
    ssh -tT  "$USERNAME"@"$(get_vm_ip)" << EOF
ssh -o StrictHostKeyChecking=no root@$MASTER_IP \
    'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
ssh -o StrictHostKeyChecking=no root@$WORKER_IP \
    'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
EOF
}

# k8s Provisioning (currently BMRA)
provision_k8s() {
    # shellcheck disable=SC2087
    ssh -tT  "$USERNAME"@"$(get_vm_ip)" << EOF
# Install BMRA
if [ ! -d "${PROJECT_ROOT}/container-experience-kits" ]; then
    curl -fsSL https://get.docker.com/ | sh
    printf "Waiting for docker service..."
    until sudo docker info; do
        printf "."
        sleep 2
    done
    git clone https://github.com/intel/container-experience-kits.git
    cd ${PROJECT_ROOT}/container-experience-kits
    git checkout v1.4.1
    git submodule update --init
    cp -r examples/group_vars examples/host_vars .
    cp ${PROJECT_ROOT}/${INSTALLER}/inventory.ini \
    ${PROJECT_ROOT}/container-experience-kits/
    cp ${PROJECT_ROOT}/${INSTALLER}/all.yml \
    ${PROJECT_ROOT}/container-experience-kits/group_vars/
    cp ${PROJECT_ROOT}/${INSTALLER}/node1.yml \
    ${PROJECT_ROOT}/container-experience-kits/host_vars/
fi
sudo service docker start
sudo docker run --rm \
-v ${PROJECT_ROOT}/container-experience-kits:/bmra \
-v ~/.ssh/:/root/.ssh/ rihabbanday/bmra-install:centos \
ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/cluster.yml
EOF
}
