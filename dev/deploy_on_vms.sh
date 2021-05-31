#!/bin/bash
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) Ericsson AB and others
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Script for end to end RI-2 deployment using Infra engine and BMRA on VMS 
# TODO Update README

set -o errexit
set -o nounset
if [ "${DEBUG:-false}" == "true" ]; then
    set -o xtrace
fi

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
# creates a virtual environment for installation of dependencies
# ---------------------------------------------------------------------
creates_virtualenv

# ---------------------------------------------------------------------
# bootstrap install prerequisites
# ---------------------------------------------------------------------
run_playbook bootstrap

# ---------------------------------------------------------------------
# Create BMRA config based on IDF and PDF
# ---------------------------------------------------------------------
run_playbook bmra-config

# ---------------------------------------------------------------------
# Provision VMs
# ---------------------------------------------------------------------
provision_hosts_vms

# TODO
# ---------------------------------------------------------------------
#  Configure Networking on the VMs
# ---------------------------------------------------------------------
#ansible-playbook -i "$CURRENTPATH"/engine/engine/inventory/inventory.ini "$CURRENTPATH"/playbooks/configure-vms.yaml

# ---------------------------------------------------------------------
# Provision k8s cluster (currently BMRA)
# ---------------------------------------------------------------------
provision_k8s_vms
