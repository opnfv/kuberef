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
        sudo virsh destroy $VM_NAME
    fi
    if sudo virsh list --all | grep "${VM_NAME}" ; then
        sudo virsh undefine $VM_NAME
    fi
        sudo rm -rf /var/lib/libvirt/images/$VM_NAME
        sleep 5
}

# Create jumphost VM

create_jump() {
# Create VM image
    sudo mkdir -p /var/lib/libvirt/images/$VM_NAME
    sudo qemu-img create -f qcow2 \
        -o backing_file=/var/lib/libvirt/images/ubuntu-18.04.qcow2 \
        /var/lib/libvirt/images/$VM_NAME/$VM_NAME.qcow2 10G

# Create VM cloud-init configuration files
    cat <<EOL > user-data
    #cloud-config
    users:
      - name: $USERNAME
        ssh-authorized-keys:
          - $(cat $HOME/.ssh/id_rsa.pub)
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        groups: sudo
        shell: /bin/bash
EOL
    cat <<EOL > meta-data
    local-hostname: $VM_NAME
EOL

# Create VM
    sudo genisoimage  -output /var/lib/libvirt/images/$VM_NAME/$VM_NAME-cidata.iso \
        -volid cidata -joliet -rock user-data meta-data

    sudo virt-install --connect qemu:///system --name $VM_NAME \
        --ram 4096 --vcpus=4 --os-type linux --os-variant ubuntu16.04 \
        --disk path=/var/lib/libvirt/images/$VM_NAME/$VM_NAME.qcow2,format=qcow2 \
        --disk /var/lib/libvirt/images/$VM_NAME/$VM_NAME-cidata.iso,device=cdrom \
        --import --network network=default --network bridge=$BRIDGE,model=rtl8139 --noautoconsole
    sleep 30
}

# Get jumphost VM IP

get_vm_ip() {
    export VM_IP=$(sudo virsh domifaddr ${VM_NAME} | \
            sed 3q | sed '$!d' |awk '{print $4}' | cut -d/ -f1)
    echo "VM IP is ${VM_IP}"
}

# Setup PXE network

setup_PXE_network() {
    get_vm_ip
    export PXE_IF=$(yq r $CURRENTPATH/hw_config/$VENDOR/idf.yaml engine.pxe_interface)
    export PXE_IF_IP=$(yq r $CURRENTPATH/hw_config/$VENDOR/pdf.yaml jumphost.interfaces.[0].address)
    export PXE_IF_MAC=$(yq r $CURRENTPATH/hw_config/$VENDOR/pdf.yaml jumphost.interfaces.[0].mac_address)
    export NETMASK=255.255.255.0
    ssh -o StrictHostKeyChecking=no -tT $USERNAME@$VM_IP << EOF
    sudo ifconfig $PXE_IF up
    sudo ifconfig $PXE_IF $PXE_IF_IP netmask $NETMASK
    sudo ifconfig $PXE_IF hw ether $PXE_IF_MAC
EOF
}

# Copy files needed by Infra engine & BMRA in the jumphost VM

copy_files_jump() {
    scp -r -o StrictHostKeyChecking=no $CURRENTPATH/{hw_config/$VENDOR/,sw_config/$INSTALLER/} \
            $USERNAME@$VM_IP:$PROJECT_ROOT
}

# Host Provisioning

provision_hosts() {
# SSH to jumphost
    ssh  -o StrictHostKeyChecking=no -tT $USERNAME@$VM_IP << EOF
# Install and run cloud-infra
    if [ ! -d "${PROJECT_ROOT}/engine" ]; then
        ssh-keygen -t rsa -N "" -f ${PROJECT_ROOT}/.ssh/id_rsa
        git clone https://gerrit.nordix.org/infra/engine.git
        cp $PROJECT_ROOT/$VENDOR/{pdf.yaml,idf.yaml} ${PROJECT_ROOT}/engine/engine
    fi
        cd ${PROJECT_ROOT}/engine/engine && ./deploy.sh -s ironic -d centos7 \
        -p file:///${PROJECT_ROOT}/engine/engine/pdf.yaml -i file:///${PROJECT_ROOT}/engine/engine/idf.yaml
EOF
}

# Setup networking on provisioned hosts (Adapt setup_network.sh according to your network setup)

setup_network() {
    export MASTER_IP=$(yq r $CURRENTPATH/hw_config/$VENDOR/pdf.yaml nodes.[0].interfaces.[0].address)
    export WORKER_IP=$(yq r $CURRENTPATH/hw_config/$VENDOR/pdf.yaml nodes.[1].interfaces.[0].address)
# SSH to jumphost
    ssh  -o StrictHostKeyChecking=no -tT $USERNAME@$VM_IP << EOF
    ssh -o StrictHostKeyChecking=no root@$MASTER_IP 'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
    ssh -o StrictHostKeyChecking=no root@$WORKER_IP 'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
EOF
}

# k8s Provisioning (currently BMRA)

provision_k8s() {
# SSH to jumphost
    ssh -o StrictHostKeyChecking=no -tT $USERNAME@$VM_IP << EOF
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
    fi
    cp ${PROJECT_ROOT}/${INSTALLER}/inventory.ini ${PROJECT_ROOT}/container-experience-kits/
    cp ${PROJECT_ROOT}/${INSTALLER}/all.yml ${PROJECT_ROOT}/container-experience-kits/group_vars/
    cp ${PROJECT_ROOT}/${INSTALLER}/node1.yml ${PROJECT_ROOT}/container-experience-kits/host_vars/
    sudo service docker start
    sudo docker run --rm -v ${PROJECT_ROOT}/container-experience-kits:/bmra -v ~/.ssh/:/root/.ssh/ \
        rihabbanday/bmra-install:centos ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/cluster.yml
EOF
}
