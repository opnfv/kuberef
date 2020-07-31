#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c)
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# TODO This will be merged in main functions.sh

sudo mkdir -p "/var/lib/libvirt/images/$1"
sudo qemu-img create -f qcow2 \
    -o backing_file=/var/lib/libvirt/images/ubuntu-18.04.qcow2 \
    "/var/lib/libvirt/images/$1/${1}.qcow2" 10G

# Create cloud-init configuration files
cat <<EOL > user-data
#cloud-config
users:
  - name: ubuntu
    ssh-authorized-keys:
      - $(cat "$HOME/.ssh/id_rsa.pub")
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
EOL
cat <<EOL > meta-data
local-hostname: $VM_NAME
EOL

sudo genisoimage  -output "/var/lib/libvirt/images/$1/$1-cidata.iso" \
    -volid cidata -joliet -rock user-data meta-data
sudo virt-customize -a "/var/lib/libvirt/images/$1/$1.qcow2" \
    --root-password password:"$ROOT_PASSWORD"
sudo virt-install --connect qemu:///system --name "$VM_NAME" \
    --ram 4096 --vcpus=4 --os-type linux --os-variant ubuntu16.04 \
    --disk path="/var/lib/libvirt/images/$1/${1}.qcow2",format=qcow2 \
    --disk "/var/lib/libvirt/images/$1/${1}-cidata.iso",device=cdrom \
    --import --network network=default \
    --network bridge="$BRIDGE",model=rtl8139 --noautoconsole
