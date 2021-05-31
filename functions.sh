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
if [ "${DEBUG:-false}" == "true" ]; then
    set -o xtrace
fi

check_prerequisites() {
    info "Check prerequisites"

    #-------------------------------------------------------------------------------
    # Check for DEPLOYMENT type
    #-------------------------------------------------------------------------------
    if ! [[ "$DEPLOYMENT" =~ ^(full|k8s)$ ]]; then
        error "Unsupported value for DEPLOYMENT ($DEPLOYMENT)"
    fi

    #-------------------------------------------------------------------------------
    # We shouldn't be running as root
    #-------------------------------------------------------------------------------
    if [[ "$(whoami)" == "root" ]] && [[ "$DEPLOYMENT" != "k8s" ]]; then
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
    # Check if Python Virtual Environment is installed
    #-------------------------------------------------------------------------------
    if ! command -v virtualenv &> /dev/null; then
        error "VirtualEnv not found. Please install."
    fi

    #-------------------------------------------------------------------------------
    # Check if PIP Installs Packages is installed
    #-------------------------------------------------------------------------------
    if ! command -v pip &> /dev/null; then
        error "PIP not found. Please install."
    fi

    #-------------------------------------------------------------------------------
    # Check is libvirt is installed
    #-------------------------------------------------------------------------------
    for tool in ansible yq virsh jq; do
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

    PXE_NETWORK=$(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/idf.yaml engine.pxe_network)
    assert_non_empty "$PXE_NETWORK" "PXE network for jump VM not defined in IDF."

    PXE_IF_INDEX=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/idf.yaml idf.net_config."$PXE_NETWORK".interface)
    assert_non_empty "$PXE_IF_INDEX" "Index of PXE interface not found in IDF."

    PXE_IF_IP=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/pdf.yaml "$host".interfaces["$PXE_IF_INDEX"].address)
    assert_non_empty "$PXE_IF_IP" "IP of PXE interface not found in PDF."

    echo "$PXE_IF_IP"
}

# Get public MAC for VM
get_host_pub_mac() {
    local PUB_NETWORK
    local PUB_IF_INDEX
    local PUB_IF_MAC

    host=$1
    assert_non_empty "$host" "get_mac - host parameter not provided"

    PUB_NETWORK=$(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/idf.yaml  engine.public_network)
    assert_non_empty "$PUB_NETWORK" "Public network for jump VM not defined in IDF."

    PUB_IF_INDEX=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/idf.yaml idf.net_config."$PUB_NETWORK".interface)
    assert_non_empty "$PUB_IF_INDEX" "Index of public interface not found in IDF."

    PUB_IF_MAC=$(yq r "$CURRENTPATH"/hw_config/"${VENDOR}"/pdf.yaml "$host".interfaces["$PUB_IF_INDEX"].mac_address)
    assert_non_empty "$PUB_IF_MAC" "MAC of public interface not found in PDF."
    echo "$PUB_IF_MAC"
}

# Get jumphost VM IP
get_vm_ip() {
    if [[ "$DEPLOYMENT" == "full" ]]; then
        ip=$(get_host_pxe_ip "jumphost")
    else
        mac=$(get_host_pub_mac "jumphost")
        JUMPHOST_NAME=$(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/pdf.yaml jumphost.name)
        ipblock=$(virsh domifaddr "$JUMPHOST_NAME" --full | grep "$mac" | awk '{print $4}' | tail -n 1)
        assert_non_empty "$ipblock" "IP subnet for VM not available."
        ip="${ipblock%/*}"
    fi
    echo "$ip"
}

# Copy files needed by Infra engine & BMRA in the jumphost VM
copy_files_jump() {
    vm_ip="$(get_vm_ip)"
    scp -r -o StrictHostKeyChecking=no \
    "$CURRENTPATH"/{hw_config/"$VENDOR"/,sw_config/"$INSTALLER"/} \
    "$USERNAME@${vm_ip}:$PROJECT_ROOT"
    if [[ "$DEPLOYMENT" != "full" ]]; then
        scp -r -o StrictHostKeyChecking=no \
        ~/.ssh/id_rsa \
        "$USERNAME@${vm_ip}:.ssh/id_rsa"
    fi
}

# Host Provisioning
provision_hosts_baremetal() {
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
./deploy.sh -s ironic -d ${DISTRO} \
-p file:///${PROJECT_ROOT}/engine/engine/pdf.yaml \
-i file:///${PROJECT_ROOT}/engine/engine/idf.yaml
EOF
}

provision_hosts_vms() {
    # shellcheck disable=SC2087
# Install and run cloud-infra
if [ ! -d "$CURRENTPATH/engine" ]; then
    git clone https://gerrit.nordix.org/infra/engine.git ${CURRENTPATH}/engine
    cp $CURRENTPATH/hw_config/$VENDOR/{pdf.yaml,idf.yaml} \
    ${CURRENTPATH}/engine/engine
fi
cd $CURRENTPATH/engine/engine
./deploy.sh -s ironic \
-p file:///${CURRENTPATH}/engine/engine/pdf.yaml \
-i file:///${CURRENTPATH}/engine/engine/idf.yaml
}

# Setup networking on provisioned hosts (Adapt setup_network.sh according to your network setup)
setup_network() {
    # Set Upper limit of number nodes in RI2 cluster (starting from 0)
    NODE_MAX_ID=$(($(yq r "$CURRENTPATH"/hw_config/"$VENDOR"/idf.yaml --length idf.kubespray.hostnames)-1))

    for idx in $(seq 0 "$NODE_MAX_ID"); do
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
provision_k8s_baremetal() {
    ansible_cmd="/bin/bash -c '"
    if [[ "$DEPLOYMENT" == "k8s" ]]; then
        ansible-playbook -i "$CURRENTPATH"/sw_config/bmra/inventory.ini "$CURRENTPATH"/playbooks/pre-install.yaml
        ansible_cmd+="yum -y remove python-netaddr; pip install --upgrade pip; pip install ansible==2.9.17; ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/k8s/patch_kubespray.yml;"
    fi
    ansible_cmd+="ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/${BMRA_PROFILE}.yml'"

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
    git clone --recurse-submodules --depth 1 https://github.com/intel/container-experience-kits.git -b v21.03 ${PROJECT_ROOT}/container-experience-kits/
    cp -r ${PROJECT_ROOT}/container-experience-kits/examples/${BMRA_PROFILE}/group_vars ${PROJECT_ROOT}/container-experience-kits/
fi
cp ${PROJECT_ROOT}/${INSTALLER}/{inventory.ini,ansible.cfg} \
    ${PROJECT_ROOT}/container-experience-kits/
cp ${PROJECT_ROOT}/${INSTALLER}/{all.yml,kube-node.yml} \
    ${PROJECT_ROOT}/container-experience-kits/group_vars/
cp ${PROJECT_ROOT}/${INSTALLER}/patched_cmk_build.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/cmk_install/tasks/main.yml
cp ${PROJECT_ROOT}/${INSTALLER}/patched_vfio.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/sriov_nic_init/tasks/bind_vf_driver.yml
cp ${PROJECT_ROOT}/${INSTALLER}/patched_rhel_packages.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/bootstrap/install_packages/tasks/rhel.yml
cp ${PROJECT_ROOT}/${INSTALLER}/patched_packages.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/bootstrap/install_packages/tasks/main.yml

sudo docker run --rm \
-e ANSIBLE_CONFIG=/bmra/ansible.cfg \
-e PROFILE=${BMRA_PROFILE} \
-v ${PROJECT_ROOT}/container-experience-kits:/bmra \
-v ~/.ssh/:/root/.ssh/ rihabbanday/bmra21.03-install:centos \
${ansible_cmd}
EOF
}

provision_k8s_vms() {
    # shellcheck disable=SC2087
# Install BMRA
if [ ! -d "${CURRENTPATH}/container-experience-kits" ]; then
    git clone --recurse-submodules --depth 1 https://github.com/intel/container-experience-kits.git -b v21.03 ${CURRENTPATH}/container-experience-kits/
    cp -r ${CURRENTPATH}/container-experience-kits/examples/${BMRA_PROFILE}/group_vars ${CURRENTPATH}/container-experience-kits/
fi
cp ${PROJECT_ROOT}/${INSTALLER}/{inventory.ini,ansible.cfg} \
    ${PROJECT_ROOT}/container-experience-kits/
cp ${PROJECT_ROOT}/${INSTALLER}/{all.yml,kube-node.yml} \
    ${PROJECT_ROOT}/container-experience-kits/group_vars/
cp ${PROJECT_ROOT}/${INSTALLER}/patched_cmk_build.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/cmk_install/tasks/main.yml
cp ${PROJECT_ROOT}/${INSTALLER}/patched_vfio.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/sriov_nic_init/tasks/bind_vf_driver.yml
cp ${PROJECT_ROOT}/${INSTALLER}/patched_rhel_packages.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/bootstrap/install_packages/tasks/rhel.yml
cp ${PROJECT_ROOT}/${INSTALLER}/patched_packages.yml \
    ${PROJECT_ROOT}/container-experience-kits/roles/bootstrap/install_packages/tasks/main.yml

ansible-playbook -i "$CURRENTPATH"/sw_config/bmra/inventory.ini "$CURRENTPATH"/playbooks/pre-install.yaml

sudo docker run --rm \
-e ANSIBLE_CONFIG=/bmra/ansible.cfg \
-e PROFILE=${BMRA_PROFILE} \
-v ${CURRENTPATH}/container-experience-kits:/bmra \
-v ~/.ssh/:/root/.ssh/ rihabbanday/bmra21.03-install:centos \
ansible-playbook -i /bmra/inventory.ini /bmra/playbooks/${BMRA_PROFILE}.yml
}

# Copy kubeconfig to the appropriate location needed by functest containers
copy_k8s_config() {
# TODO Use Kubespray variables in BMRA to simplify this
    MASTER_IP=$(get_host_pxe_ip "nodes[0]")
    # shellcheck disable=SC2087
    ssh -o StrictHostKeyChecking=no -tT "$USERNAME"@"$(get_vm_ip)" << EOF
scp -o StrictHostKeyChecking=no -q root@$MASTER_IP:/root/.kube/config ${PROJECT_ROOT}/kubeconfig
EOF

# Copy kubeconfig from Jump VM to appropriate location in Jump Host
# Direct scp to the specified location doesn't work due to permission/ssh-keys
    scp  -o StrictHostKeyChecking=no "$USERNAME"@"$(get_vm_ip)":"${PROJECT_ROOT}"/kubeconfig kubeconfig
    if [ -d "/home/opnfv/functest-kubernetes" ]; then
        sudo cp kubeconfig /home/opnfv/functest-kubernetes/config
    fi
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
