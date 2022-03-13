#!/usr/bin/env bash

echo "This doesn't work out of the box. We need to debug and fix the Dockerfile (no PVs are provisioned)."

## "Fixed" this for now be running:
#docker pull mauilion/hostpath-provisioner:dev
#docker tag mauilion/hostpath-provisioner:dev jmanders/k8s-hostpath-provisioner:0.9.2
#docker push jmanders/k8s-hostpath-provisioner:0.9.2

exit 1


this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../../../../env.sh"

set -euo pipefail

PROVISIONER_PATH="/Users/jeroen_manders/github.com/jeroenmanders/sig-storage-lib-external-provisioner/examples/hostpath-provisioner"

if [ ! -d "$PROVISIONER_PATH" ]; then
  log_warn "Provisioner source not available at $PROVISIONER_PATH."
  log_warn "Clone repo there: git clone git@github.com:jeroenmanders/sig-storage-lib-external-provisioner.git"
  log_warn "And try again."
  exit 1
fi

read -p "Enter tag (0.9.0): " tag

[[ -z "$tag" ]] && log_fatal "No tag specified."

log_info "Building local Docker image."
cd "$PROVISIONER_PATH"
make
docker tag hostpath-provisioner:latest jmanders/k8s-hostpath-provisioner:$tag
docker push jmanders/k8s-hostpath-provisioner:$tag
