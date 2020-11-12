#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) Ericsson AB and others
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

info() {
    _print_msg "INFO" "$1"
}

error() {
    _print_msg "ERROR" "$1"
    exit 1
}

_print_msg() {
    echo "$(date +%H:%M:%S) - $1: $2"
}

assert_non_empty() {
    if [ -z "$1" ]; then
        error "$2"
    fi
}

check_prerequisites() {
    info "Check prerequisites"

    #-------------------------------------------------------------------------------
    # We shouldn't be running as root
    #-------------------------------------------------------------------------------
    if [[ "$(whoami)" == "root" ]]; then
        error "This script must not be run as root! Please switch to a regular user before running the script."
    fi

    #-------------------------------------------------------------------------------
    # Check for passwordless sudo
    #-------------------------------------------------------------------------------
    if ! sudo -n "true"; then
        error "passwordless sudo is needed for '$(id -nu)' user."
    fi

    #-------------------------------------------------------------------------------
    # Check if SSH key exists
    #-------------------------------------------------------------------------------
    if [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        error "You must have SSH keypair in order to run this script!"
    fi

    #-------------------------------------------------------------------------------
    # We are using sudo so we need to make sure that env_reset is not present
    #-------------------------------------------------------------------------------
    sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers

    #-------------------------------------------------------------------------------
    # Check if some tools are installed
    #-------------------------------------------------------------------------------
    for tool in ansible yq virsh; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool not found. Please install."
        fi
    done

    #-------------------------------------------------------------------------------
    # Check if user belongs to libvirt's group
    #-------------------------------------------------------------------------------
    libvirt_group="libvirt"
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    if [ "${ID,,}" == "ubuntu" ] && [ "$VERSION_ID" == "16.04" ]; then
        libvirt_group+="d"
    fi
    if ! groups | grep "$libvirt_group"; then
        error "$(id -nu) user doesn't belong to $libvirt_group group."
    fi
}

# Get jumphost VM PXE IP
get_host_pxe_ip() {
    local PXE_NETWORK
    local PXE_IF_INDEX
    local PXE_IF_IP

    host=$1
    assert_non_empty "$host" "get_ip - host parameter not provided"

    PXE_NETWORK=$(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/idf.yaml  engine.pxe_network)
    assert_non_empty "$PXE_NETWORK" "PXE network for jump VM not defined in IDF."

    PXE_IF_INDEX=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/idf.yaml idf.net_config."$PXE_NETWORK".interface)
    assert_non_empty "$PXE_IF_INDEX" "Index of PXE interface not found in IDF."

    PXE_IF_IP=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/pdf.yaml "$host".interfaces["$PXE_IF_INDEX"].address)
    assert_non_empty "$PXE_IF_IP" "IP of PXE interface not found in PDF."

    echo "$PXE_IF_IP"
}

# Get jumphost VM IP
get_vm_ip() {
    ip=$(get_host_pxe_ip "jumphost")
    echo "$ip"
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
    ssh -o StrictHostKeyChecking=no -tT "$USERNAME"@"$(get_vm_ip)" << EOF
# Install and run cloud-infra
if [ ! -d "${PROJECT_ROOT}/engine" ]; then
    ssh-keygen -t rsa -N "" -f ${PROJECT_ROOT}/.ssh/id_rsa
    git clone https://gerrit.nordix.org/infra/engine.git
    cp $PROJECT_ROOT/$VENDOR/{pdf.yaml,idf.yaml} \
    ${PROJECT_ROOT}/engine/engine
fi
cd ${PROJECT_ROOT}/engine/engine
./deploy.sh -s ironic -d centos7 \
-p file:///${PROJECT_ROOT}/engine/engine/pdf.yaml \
-i file:///${PROJECT_ROOT}/engine/engine/idf.yaml
EOF
}

# Setup networking on provisioned hosts (Adapt setup_network.sh according to your network setup)
setup_network() {
# Set Upper limit of number nodes in RI2 cluster (starting from 0)
NODE_MAX_ID=$(($(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/idf.yaml --length idf.kubespray.hostnames)-1))

for idx in $(seq 0 "$NODE_MAX_ID")
do
    NODE_IP=$(get_host_pxe_ip "nodes[${idx}]")
# SSH to jumphost
    # shellcheck disable=SC2087
    ssh -o StrictHostKeyChecking=no -tT "$USERNAME"@"$(get_vm_ip)" << EOF
ssh -o StrictHostKeyChecking=no root@${NODE_IP} \
    'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
EOF
done
}

# k8s Provisioning (currently BMRA)
provision_k8s() {
    # shellcheck disable=SC2087
    ssh -o StrictHostKeyChecking=no -tT "$USERNAME"@"$(get_vm_ip)" << EOF
# Install BMRA
if ! command -v docker; then
    curl -fsSL https://get.docker.com/ | sh
    printf "Waiting for docker service..."
    until sudo docker info; do
        printf "."
        sleep 2
    done
fi
if [ ! -d "${PROJECT_ROOT}/container-experience-kits" ]; then
    git clone --recurse-submodules --depth 1 https://github.com/intel/container-experience-kits.git -b v1.4.1 ${PROJECT_ROOT}/container-experience-kits/
    cp -r ${PROJECT_ROOT}/container-experience-kits/examples/group_vars ${PROJECT_ROOT}/container-experience-kits/
#TODO Remove this once the reported issue is fixed in the next BMRA Release
    sed -i '/\openshift/a \    extra_args: --ignore-installed PyYAML' \
        ${PROJECT_ROOT}/container-experience-kits/roles/net-attach-defs-create/tasks/main.yml
fi
cp ${PROJECT_ROOT}/${INSTALLER}/inventory.ini \
    ${PROJECT_ROOT}/container-experience-kits/
cp ${PROJECT_ROOT}/${INSTALLER}/{all.yml,kube-node.yml} \
    ${PROJECT_ROOT}/container-experience-kits/group_vars/
sudo docker run --rm \
-e ANSIBLE_CONFIG=/bmra/ansible.cfg \
-v ${PROJECT_ROOT}/container-experience-kits:/bmra \
-v ~/.ssh/:/root/.ssh/ rihabbanday/bmra-install:centos \
ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/cluster.yml
EOF
}
