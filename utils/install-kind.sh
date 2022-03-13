#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function install_kind() {
  local VERSION="v0.11.1"
  curl -sLo ./kind https://kind.sigs.k8s.io/dl/$VERSION/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
}

install_kind

