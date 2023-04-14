#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


source ./virtualbox.sh
source ./consul.sh

set -e

number_of_datacenters=3
while getopts n: flag
do
    case "${flag}" in
        n) number_of_datacenters=${OPTARG};;
    esac
done

PRIMARY_DATACENTER=""

for (( i=1; i<=${number_of_datacenters}; i++ ))
do
    CLUSTER="dc${i}"

    echo "******* SET UP CLUSTER ${CLUSTER} *******"

    if grep "${CLUSTER}" .minikubes.state 2>/dev/null; then
        break
    fi

    echo "[ SET UP HOST-ONLY NETWORK FOR ${CLUSTER} ]"
    NETWORK=$(setup_network)

    echo "${CLUSTER} ${NETWORK}" >> .minikubes.state

    ADDRESS="$(vboxmanage list hostonlyifs | sed -n '/'${NETWORK}'/, /Name/p' | grep IPAddress | sed 's/.*:\s*//' | tr -d ' ')"
    NETMASK="$(vboxmanage list hostonlyifs | sed -n '/'${NETWORK}'/, /Name/p' | grep NetworkMask: | sed 's/.*:\s*//' | tr -d ' ')"

    echo "[ SET UP DCHP SERVER FOR ${NETWORK} HOST-ONLY NETWORK ]"
    DHCP="$(calculate_dhcp_server_ip ${ADDRESS} ${NETMASK})"
    LOWER_IP_ADDRESS="$(calculate_lower_ip ${ADDRESS} ${NETMASK})"
    UPPER_IP_ADDRESS="$(calculate_upper_ip ${ADDRESS} ${NETMASK})"
    setup_dhcp ${NETWORK} ${NETMASK} ${DHCP} ${LOWER_IP_ADDRESS} ${UPPER_IP_ADDRESS}

    echo "[ START KUBERNETES CLUSTER FOR ${CLUSTER} ]"
    minikube start -p ${CLUSTER} --driver=virtualbox --addons=metallb --host-only-cidr="${ADDRESS}/24"

    echo "[ CONFIGURE METALLB FOR ${CLUSTER} ]"
    sed -e 's/LOWER_IP_ADDRESS/'${LOWER_IP_ADDRESS}'/g' -e 's/UPPER_IP_ADDRESS/'${UPPER_IP_ADDRESS}'/g' metallb/configmap.yaml | kubectl apply -f -

    echo "[ INSTALL CONSUL FOR ${CLUSTER} ]"
    install_consul ${CLUSTER}

    echo "[ SET UP MESH GATEWAY FOR ${CLUSTER} ]"
    install_mesh_gateway ${CLUSTER}

    get_cluster_information ${CLUSTER}

    echo "[ SET UP PEERING FOR ${CLUSTER} ]"
    while read -r line; do
        cluster=($line)
        if [[ "${cluster[0]}" != ${CLUSTER} ]]; then
            generate_peering_token ${cluster[0]} ${CLUSTER}
        fi
    done < .consul.state

    echo ""
done