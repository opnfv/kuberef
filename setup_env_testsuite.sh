#!/bin/bash

# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) Ericsson AB and others
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

# Script to run RC2 testcases suite on the K8s cluster
# deployed by deploy.sh. More info to be added in README

set -o xtrace
set -o errexit
set -o nounset

# Get path information
CURRENTPATH=$(git rev-parse --show-toplevel)
export CURRENTPATH

# Source env variables & functions
# shellcheck source=./deploy.env
source "$CURRENTPATH/deploy.env"
# shellcheck source=./functions.sh
source "$CURRENTPATH/functions.sh"

# ---------------------------------------------------------------------
# Setup env to run RC2 Conformance Suite
# ---------------------------------------------------------------------
setup_env_testsuite
