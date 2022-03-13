#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../env.sh"

if [ -z "${CLUSTER_MODE-}" ]; then
  if [ "$(uname)" == "Darwin" ]; then
    log_info "Setting cluster mode to 'KIND' because we're running under 'Darwin'."
    export CLUSTER_MODE="KIND"
  else
    log_info "Setting cluster mode to 'VIRTUALBOX' because we're not running under 'Darwin'."
    export CLUSTER_MODE="VIRTUALBOX"
  fi
fi
export SETTINGS_DIR="$REPO_DIR/kubernetes/settings"
export KIND_DIR="$REPO_DIR/kubernetes/kind"
export VIRTUALBOX_DIR="$REPO_DIR/kubernetes/virtualbox"

export VBOX_CONFIG_FILE="$SETTINGS_DIR/005-virtualbox.local.yaml"
export K8S_CONFIG_FILE="$SETTINGS_DIR/010-kubernetes.local.yaml"
export MAIN_CONFIG_FILE="$SETTINGS_DIR/001-settings.local.yaml"
export REGISTRY_CONFIG_FILE="$SETTINGS_DIR/050-registry.local.yaml"
export VAULT_CONFIG_FILE="$SETTINGS_DIR/100-vault.local.yaml"
export KANIKO_CONFIG_FILE="$SETTINGS_DIR/100-kaniko.local.yaml"

export USER_HOME="$(eval echo ~)"

function install_products() {
  if [ "$CLUSTER_MODE" == "VIRTUALBOX" ]; then
    get_var "PRODUCTS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .products" ""
  else
    get_var "PRODUCTS" "$KIND_PRODUCTS_CONFIG_FILE" ".products" ""
  fi

  for product in $(echo "$PRODUCTS" | yq -o json | jq -cr '.[]'); do
    local name="$(echo "$product" | jq -r '.name')"
    local install="$(echo "$product" | jq -r '."auto-install"')"
    local file="$(echo "$product" | jq -r '."install-file"')"
    if [ "$install" != "true" ]; then
      log_info "Not auto-installing product '$name'."
      continue
    fi
    log_info "Installing product '$name' from '$REPO_DIR/kubernetes/$file'."
    "$REPO_DIR/kubernetes/$file"
  done
}
