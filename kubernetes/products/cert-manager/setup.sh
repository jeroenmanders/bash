#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function run_yamls() {
  log_info "Applying yaml files."
  kubectl apply -k ./kustomize
}

run_yamls
