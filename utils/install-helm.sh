#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function install_helm() {
  if [ "$(uname)" == "Darwin" ]; then
    log_info "Installing Helm using Brew."
    brew install helm
  else
    log_info "Installing Helm."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
  fi
}

install_helm
