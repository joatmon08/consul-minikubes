#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


source ./virtualbox.sh

while read -r line; do
    vm=($line)

    echo "### Delete ${vm[0]} ###"
    minikube delete -p ${vm[0]}

    echo "### Delete host-only network ${vm[1]} ###"
    delete_network ${vm[1]} 2>/dev/null
done < .minikubes.state

rm -rf .minikubes.state
rm -rf consul/federation-secrets.yaml
rm -rf .consul.state