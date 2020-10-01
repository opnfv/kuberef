#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) Ericsson AB and others
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

if [ "${DEBUG:-false}" == "true" ]; then
    set -o xtrace
fi

check_prerequisites() {
    echo "Info  : Check prerequisites"

    #-------------------------------------------------------------------------------
    # We shouldn't be running as root
    #-------------------------------------------------------------------------------
    if [[ "$(whoami)" == "root" ]]; then
        echo "ERROR : This script must not be run as root!"
        echo "        Please switch to a regular user before running the script."
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # Check for passwordless sudo
    #-------------------------------------------------------------------------------
    if ! sudo -n "true"; then
        echo "ERROR : passwordless sudo is needed for '$(id -nu)' user."
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # Check if SSH key exists
    #-------------------------------------------------------------------------------
    if [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        echo "ERROR : You must have SSH keypair in order to run this script!"
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # We are using sudo so we need to make sure that env_reset is not present
    #-------------------------------------------------------------------------------
    sudo sed -i "s/^Defaults.*env_reset/#&/" /etc/sudoers

    #-------------------------------------------------------------------------------
    # Check if Python Virtual Environment is installed
    #-------------------------------------------------------------------------------
    if ! command -v virtualenv &> /dev/null; then
        echo "ERROR : VirtualEnv not found. Please install."
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # Check if PIP Installs Packages is installed
    #-------------------------------------------------------------------------------
    if ! command -v pip &> /dev/null; then
        echo "ERROR : PIP not found. Please install."
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # Check is libvirt is installed
    #-------------------------------------------------------------------------------
    if ! command -v virsh &> /dev/null; then
        echo "ERROR : Libvirt not found. Please install."
        exit 1
    fi

    #-------------------------------------------------------------------------------
    # Check if user belongs to libvirt's group
    #-------------------------------------------------------------------------------
    libvirt_group="libvirt"
    # shellcheck disable=SC1091
    source /etc/os-release || source /usr/lib/os-release
    if [ "${ID,,}" == "ubuntu" ] && [ "$VERSION_ID" == "16.04" ]; then
        libvirt_group+="d"
    fi
    if ! groups | grep " $libvirt_group "; then
        echo "ERROR : $(id -nu) user doesn't belong to $libvirt_group group."
        exit 1
    fi
}

# Get jumphost VM IP
get_host_pxe_ip() {
    local PXE_NETWORK
    local PXE_IF_INDEX
    local PXE_IF_IP

    host=$1
    if [[ "$host" == "" ]]; then
        echo "ERROR : get_ip - host parameter not provided"
        exit 1
    fi

    PXE_NETWORK=$(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/idf.yaml  engine.pxe_network)
    if [[ "$PXE_NETWORK" == "" ]]; then
        echo "ERROR : PXE network for jump VM not defined in IDF."
        exit 1
    fi

    PXE_IF_INDEX=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/idf.yaml idf.net_config."$PXE_NETWORK".interface)
    if [[ "$PXE_IF_INDEX" == "" ]]; then
        echo "ERROR : Index of PXE interface not found in IDF."
        exit 1
    fi

    PXE_IF_IP=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/pdf.yaml "$host".interfaces["$PXE_IF_INDEX"].address)
    if [[ "$PXE_IF_IP" == "" ]]; then
        echo "ERROR : IP of PXE interface not found in PDF."
        exit 1
    fi
    echo "$PXE_IF_IP"
}

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
    MASTER_IP=$(get_host_pxe_ip "nodes[0]")
    WORKER_IP=$(get_host_pxe_ip "nodes[1]")
# SSH to jumphost
    # shellcheck disable=SC2087
    ssh -o StrictHostKeyChecking=no -tT "$USERNAME"@"$(get_vm_ip)" << EOF
ssh -o StrictHostKeyChecking=no root@$MASTER_IP \
    'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
ssh -o StrictHostKeyChecking=no root@$WORKER_IP \
    'bash -s' <  ${PROJECT_ROOT}/${VENDOR}/setup_network.sh
EOF
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

# Creates a python virtual environment
creates_virtualenv() {
    if [  ! -d "$CURRENTPATH/.venv" ]; then
        virtualenv .venv
    fi
    # shellcheck disable=SC1090
    source "$CURRENTPATH/.venv/bin/activate"
    pip install -r "$CURRENTPATH/requirements.txt"
}

# Executes a specific Ansible playbook
run_playbook() {
    ansible_cmd="$(command -v ansible-playbook) -i $CURRENTPATH/inventory/localhost.ini -e ansible_python_interpreter=$(command -v python)"
    if [ "${DEBUG:-false}" == "true" ]; then
        ansible_cmd+=" -vvv"
    fi
    eval "$ansible_cmd $CURRENTPATH/playbooks/${1}.yaml"
}
