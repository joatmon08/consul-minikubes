#!/bin/bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0


set -e

kubectl --context dc3 apply -f example/dc3
kubectl --context dc2 apply -f example/dc2
kubectl --context dc1 apply -f example/dc1