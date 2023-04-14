#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


calculate_dhcp_server_ip() {
    ip=$1; mask=$2

    IFS=. read -r i1 i2 i3 i4 <<< "$ip"
    IFS=. read -r m1 m2 m3 m4 <<< "$mask"
    echo "$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$(((i4 & m4)+2))"
}

calculate_lower_ip() {
    ip=$1; mask=$2

    IFS=. read -r i1 i2 i3 i4 <<< "$ip"
    IFS=. read -r m1 m2 m3 m4 <<< "$mask"
    echo "$((i1 & m1)).$((i2 & m2)).$((i3 & m3)).$(((i4 & m4)+3))"
}

calculate_upper_ip() {
    ip=$1; mask=$2

    IFS=. read -r i1 i2 i3 i4 <<< "$ip"
    IFS=. read -r m1 m2 m3 m4 <<< "$mask"
    echo "$((i1 & m1 | 255-m1)).$((i2 & m2 | 255-m2)).$((i3 & m3 | 255-m3)).$(((i4 & m4 | 255-m4)-1))"
}

setup_network () {
    NETWORK=$(vboxmanage hostonlyif create 2>/dev/null | cut -d"'" -f2)
    until vboxmanage list hostonlyifs | grep ${NETWORK} > /dev/null; do
        sleep 1
    done
    echo ${NETWORK}
}

setup_dhcp () {
    NETWORK=$1; NETMASK=$2; DHCP=$3; LOWER_IP=$4; UPPER_IP=$5

    vboxmanage dhcpserver add --ifname ${NETWORK} \
                              --server-ip=${DHCP} \
                              --netmask=${NETMASK} \
                              --lower-ip=${LOWER_IP} \
                              --upper-ip=${UPPER_IP} \
                              --enable
}

delete_network () {
    NETWORK=$1
    vboxmanage dhcpserver remove --ifname ${NETWORK}
    vboxmanage hostonlyif remove ${NETWORK}
}