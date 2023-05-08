#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


setup_helm () {
    helm repo add hashicorp https://helm.releases.hashicorp.com
}

install_consul () {
    kubectl config use-context ${1}
    sed -e 's/DATACENTER/'${1}'/g' consul/values.yaml | helm upgrade --install consul hashicorp/consul --create-namespace -n consul -f -
    kubectl rollout status -n consul --timeout=120s deployment/consul-connect-injector
}

generate_peering_token () {
    sed -e 's/SOURCE/'${1}'/g' \
        -e 's/TARGET/'${2}'/g' \
        consul/peering-acceptor.yaml | kubectl --context ${1} -n consul apply -f -

    sleep 10

    kubectl --context ${1} -n consul get secret peering-token-${1}-to-${2} --output yaml | \
        kubectl --context ${2} -n consul apply -f -

    sed -e 's/SOURCE/'${1}'/g' \
        -e 's/TARGET/'${2}'/g' \
        consul/peering-dialer.yaml | kubectl --context ${2} -n consul apply -f -
}

install_mesh_gateway () {
    kubectl --context ${1} -n consul apply -f consul/mesh.yaml
    kubectl --context ${1} -n consul apply -f consul/proxy-defaults.yaml
}

get_cluster_information () {
    TOKEN=$(kubectl --context ${1} -n consul get secrets consul-bootstrap-acl-token  -o=jsonpath='{.data.token}' | base64 -d)
    echo "${1} ${TOKEN}" >> .consul.state
}