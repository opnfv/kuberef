#!/bin/bash

set -x

sudo mkdir /var/lib/libvirt/images/$1
sudo qemu-img create -f qcow2 -o backing_file=/var/lib/libvirt/images/ubuntu-18.04.qcow2 /var/lib/libvirt/images/$1/"$1".qcow2
sudo qemu-img info /var/lib/libvirt/images/$1/"$1".qcow2
sudo qemu-img resize /var/lib/libvirt/images/$1/"$1".qcow2 10G
sudo genisoimage  -output /var/lib/libvirt/images/$1/"$1"-cidata.iso -volid cidata -joliet -rock user-data meta-data

sudo virt-install --connect qemu:///system --virt-type kvm --name $VM_NAME --ram 4096 --vcpus=4 --os-type linux --os-variant ubuntu16.04 --disk path=/var/lib/libvirt/images/$1/"$1".qcow2,format=qcow2 --disk /var/lib/libvirt/images/$1/"$1"-cidata.iso,device=cdrom --import --network network=default --network bridge=$BRIDGE --noautoconsole
