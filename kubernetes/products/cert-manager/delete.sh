#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

#function delete_resources() {
#  log_info "Applying yaml files."
#  cat $(ls -r yaml/*.yaml) | envsubst | kubectl delete -n "$SERVICE_NAMESPACE" -f -
#}
#
#delete_resources
