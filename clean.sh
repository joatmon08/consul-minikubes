#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


source ./docker.sh

while read -r line; do
    vm=($line)

    echo "### Delete ${vm[0]} ###"
    minikube delete -p ${vm[0]}
done < .minikubes.state

echo "### Delete network ###"
delete_network metallb 2>/dev/null

rm -rf .minikubes.state
rm -rf consul/federation-secrets.yaml
rm -rf .consul.state