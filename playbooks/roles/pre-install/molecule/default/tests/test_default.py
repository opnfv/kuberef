# SPDX-FileCopyrightText: 2020 Samsung Electronics
#
# SPDX-License-Identifier: Apache-2.0

import os
import pytest

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')
def test_requirements_installed(host):
    for pkg in ["lshw", "pciutils", "ethtool"]:
        assert host.package(pkg).is_installed
