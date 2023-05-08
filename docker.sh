#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

setup_network () {
    SUBNET="172.28.0.0/16"
    IP_RANGE="172.28.0.0/24"
    NETWORK_ID=$(docker network create metallb --subnet=${SUBNET} --ip-range=${IP_RANGE})
}

connect_network () {
    docker network connect metallb ${1}
}

get_lower_metallb_range () {
    echo "172.28.${1}.3"
}

get_upper_metallb_range () {
    echo "172.28.${1}.254"
}

delete_network () {
    docker network rm ${1}
}