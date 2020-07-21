# Adapt this script according to your network setup
# TODO Get networking info from PDF & IDF

#!/bin/bash

echo nameserver 8.8.8.8 > /etc/resolv.conf
sed -i 's/NM_CONTROLLED=yes/NM_CONTROLLED=no/g' /etc/sysconfig/network-scripts/ifcfg-eth2
echo GATEWAY=10.10.190.1 >> /etc/sysconfig/network-scripts/ifcfg-eth2 
ifup eth2

