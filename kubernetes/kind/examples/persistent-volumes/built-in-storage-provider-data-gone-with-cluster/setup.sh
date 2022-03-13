#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../../../../env.sh"

set -euo pipefail

log_info "Creating cluster"
kind create cluster --config kind-cluster.yaml

log_info "Scheduling a pod with a pvc"
kubectl apply -f test-resources.yaml

