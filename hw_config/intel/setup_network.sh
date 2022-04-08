#!/bin/bash

# SPDX-FileCopyrightText: 2021 Anuket contributors
#
# SPDX-License-Identifier: Apache-2.0

# Adapt this script according to your network setup
# TODO Get networking info from PDF & IDF
# TODO Add support in infra engine to update nameserver, etc
# files with correct info

sed -i 's/NM_CONTROLLED=yes/NM_CONTROLLED=no/g' \
/etc/sysconfig/network-scripts/ifcfg-eth2
{
  echo "GATEWAY=10.10.190.1"
  echo "DNS1=8.8.8.8"
  echo "DNS2=8.8.4.4"
} >> /etc/sysconfig/network-scripts/ifcfg-eth2
ifup eth2
