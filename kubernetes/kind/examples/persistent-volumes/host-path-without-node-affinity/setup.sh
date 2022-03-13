#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../../../../env.sh"

set -euo pipefail

mkdir -p /opt/mnt/hostpath-provisioner

log_info "Creating cluster"
kind create cluster --config kind-cluster.yaml

log_info "The provisioner Docker container mauilion/hostpath-provisioner:dev is based on https://github.com/kubernetes-sigs/sig-storage-lib-external-provisioner/tree/master"
log_info "This is probably how to create the Docker container: https://github.com/kubernetes-sigs/sig-storage-lib-external-provisioner/tree/master/examples/hostpath-provisioner"

