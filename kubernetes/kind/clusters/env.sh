#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../env.sh"

function setup_cluster() {
  local cluster_name="$1"
  local kind_config="$2"
  log_info "Creating cluster '$cluster_name' using '$kind_config'."
  kind create cluster --name "$cluster_name" --config "$kind_config"
  install_products
}

function delete_cluster() {
  local cluster_name="$1"
  kind delete cluster --name "$cluster_name"
}


