#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


source ./consul.sh
source ./docker.sh

set -e

number_of_datacenters=3
while getopts n: flag
do
    case "${flag}" in
        n) number_of_datacenters=${OPTARG};;
    esac
done

PRIMARY_DATACENTER=""

ADDRESS=$(setup_network)

for (( i=1; i<=${number_of_datacenters}; i++ ))
do
    CLUSTER="dc${i}"

    echo "******* SET UP CLUSTER ${CLUSTER} *******"

    if grep "${CLUSTER}" .minikubes.state 2>/dev/null; then
        break
    fi

    echo "${CLUSTER}" >> .minikubes.state

    echo "[ START KUBERNETES CLUSTER FOR ${CLUSTER} ]"
    minikube start -p ${CLUSTER} --driver=docker --addons=metallb

    echo "[ SET UP METALLB NETWORK FOR ${CLUSTER} ]"
    connect_network ${CLUSTER}

    LOWER_IP_ADDRESS=$(get_lower_metallb_range ${i})
    UPPER_IP_ADDRESS=$(get_upper_metallb_range ${i})

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