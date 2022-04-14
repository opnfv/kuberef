#!/bin/bash

# SPDX-FileCopyrightText: 2021 Anuket contributors
#
# SPDX-License-Identifier: Apache-2.0

# Adapt this script according to your network setup
# TODO Get networking info from PDF & IDF
# TODO Add support in infra engine to update nameserver, etc
# files with correct info

echo nameserver 8.8.8.8 > /etc/resolv.conf
sed -i '25idns=none' /etc/NetworkManager/NetworkManager.conf
sed -i 's/NM_CONTROLLED=yes/NM_CONTROLLED=no/g' \
/etc/sysconfig/network-scripts/ifcfg-eth2
echo GATEWAY=10.10.190.1 >> /etc/sysconfig/network-scripts/ifcfg-eth2
ifup eth2
