#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../env.sh"

function setup_cluster() {
  local cluster_name="$1"
  local kind_config="$2"
  log_info "Creating cluster '$cluster_name' using '$kind_config'."
  kind create cluster --name "$cluster_name" --config "$kind_config"
  #install_tools
  #install_products
}

function delete_cluster() {
  local cluster_name="$1"
  kind delete cluster --name "$cluster_name"
}

function install_tools() {
  local system_namespace="kube-system"

#  log_info "Applying resources from ../products/kubernetes-resources/"
#  cat ../../products/kubernetes-resources/* | kubectl apply -n "$system_namespace" -f -

#  get_var "INSTALL_LOCAL_PROVISIONERS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .install-local-provisioner" "false"
#  if [ "$INSTALL_LOCAL_PROVISIONERS" == "true" ]; then
#    log_info "Installing Helm chart 'sig-storage-local-static-provisioner'."
#    local chart="../../charts/sig-storage-local-static-provisioner"
#    helm install -f "../../charts/local-provisioner-values.yaml" --namespace "$system_namespace" \
#      sig-storage-local-static-provisioner  "$chart"
#  else
#    log_warn "Not installing local provisioner because setting 'install-local-provisioner' is not 'true'."
#  fi
}

