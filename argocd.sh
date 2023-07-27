#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

source ./docker.sh

set -e

install_argocd() {
    ARGOCD_VERSION="2.6.13"
    kubectl --context ${1} create namespace argocd
    kubectl --context ${1} -n argocd apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml
    kubectl --context ${1} -n argocd rollout status deployment/argocd-server --timeout=3m
}

install_jaeger () {
    kubectl config use-context ${1}
    kubectl apply -f argocd/jaeger-application.yaml
}

install_consul () {
    kubectl config use-context ${1}
    kubectl apply -f argocd/consul-project.yaml
    sed -e 's/DATACENTER/'${1}'/g' argocd/consul-application.yaml | kubectl apply -f -
}

get_cluster_information () {
    TOKEN=$(kubectl --context ${1} -n consul get secrets consul-bootstrap-acl-token  -o=jsonpath='{.data.token}' | base64 -d)
    echo "${1} ${TOKEN}" >> .consul.state
}

number_of_datacenters=1
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

    if [[ "${i}" == 1 ]]; then
        echo "[ START ARGOCD FOR ${CLUSTER} ]"
        install_argocd ${CLUSTER}
    else
        echo "[ ADD CLUSTER ${CLUSTER} to ARGOCD ]"
        argocd cluster add ${CLUSTER}
    fi

    echo "[ INSTALL JAEGER FOR ${CLUSTER} WITH ARGOCD ]"
    install_jaeger ${CLUSTER}

    echo "[ INSTALL CONSUL FOR ${CLUSTER} WITH ARGOCD ]"
    install_consul ${CLUSTER}

    get_cluster_information ${CLUSTER}
done