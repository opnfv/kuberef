#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) Ericsson AB and others
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

set -o xtrace
set -o errexit
set -o nounset

# Script for end to end RI-2 deployment using Infra engine and BMRA.
# Please refer to README for detailed information.

# Get path information
DIRECTORY=$(readlink -f "$0")
export CURRENTPATH=$(dirname "$DIRECTORY")

# Source env variables & functions
source "$CURRENTPATH/deploy.env"
source "$CURRENTPATH/functions.sh"

# ---------------------------------------------------------------------
# bootstrap install prerequisites
# ---------------------------------------------------------------------
ansible-playbook -i "$CURRENTPATH"/kuberef/inventory/localhost.ini \
    "$CURRENTPATH"/kuberef/playbooks/bootstrap.yaml

# ---------------------------------------------------------------------
# Create jump VM from which the installation is performed
# ---------------------------------------------------------------------
ansible-playbook -i "$CURRENTPATH"/kuberef/inventory/localhost.ini \
    "$CURRENTPATH"/kuberef/playbooks/jump-vm.yaml

# ---------------------------------------------------------------------
# Copy files needed by Infra engine & BMRA in the jumphost VM
# ---------------------------------------------------------------------
copy_files_jump

# ---------------------------------------------------------------------
# Provision remote hosts
# ---------------------------------------------------------------------
provision_hosts

# ---------------------------------------------------------------------
# Setup networking (Adapt according to your network setup)
# ---------------------------------------------------------------------
setup_network

# ---------------------------------------------------------------------
# Provision k8s cluster (currently BMRA)
# ---------------------------------------------------------------------
provision_k8s
