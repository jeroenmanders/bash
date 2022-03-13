#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../../../../env.sh"

set -euo pipefail

mkdir -p /opt/mnt/local-path-provisioner

log_info "Creating cluster"
kind create cluster --config kind-cluster.yaml


