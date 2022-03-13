#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../../../../env.sh"

set -euo pipefail

log_info "Testing the host path without node affinity cluster"
kubectl apply -f test-resources.yaml

log_info "You can now go into the pod and write to /pvc. Results will be under /opt/mnt/hostpath-provisioner/<pvc-id>"
