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
CURRENTPATH=$(git rev-parse --show-toplevel)
export CURRENTPATH

# shellcheck source=./functions.sh
source "$CURRENTPATH/functions.sh"
# shellcheck source=./deploy.env
source "$CURRENTPATH/deploy.env"

# ---------------------------------------------------------------------
# check installation and runtime prerequisites
# ---------------------------------------------------------------------
check_prerequisites

# ---------------------------------------------------------------------
# bootstrap install prerequisites
# ---------------------------------------------------------------------
run_playbook bootstrap

# ---------------------------------------------------------------------
# Create jump VM from which the installation is performed
# ---------------------------------------------------------------------
run_playbook jump-vm

# ---------------------------------------------------------------------
# Create BMRA config based on IDF and PDF
# ---------------------------------------------------------------------
run_playbook bmra-config

# ---------------------------------------------------------------------
# Copy files needed by Infra engine & BMRA in the jumphost VM
# ---------------------------------------------------------------------
copy_files_jump

# ---------------------------------------------------------------------
# Provision remote hosts
# Setup networking (Adapt according to your network setup)
# ---------------------------------------------------------------------
if [[ "$DEPLOYMENT" == "full" ]]; then
    provision_hosts
    setup_network
fi

# ---------------------------------------------------------------------
# Provision k8s cluster (currently BMRA)
# ---------------------------------------------------------------------
provision_k8s

# ---------------------------------------------------------------------
# Copy kubeconfig to desired location
# ---------------------------------------------------------------------
copy_k8s_config

