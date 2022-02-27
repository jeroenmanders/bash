#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

# cmctl is the cert-manager CLI

CMCTL_VERSION="v1.7.1"

function ensure_cmctl() {
  log_info "Installing cmctl $CMCTL_VERSION."
  OS=$(go env GOOS); ARCH=$(go env GOARCH); curl -sSL -o cmctl.tar.gz https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cmctl-$OS-$ARCH.tar.gz
  tar xzf cmctl.tar.gz
  sudo mv cmctl /usr/local/bin
  rm cmctl.tar.gz
}

ensure_cmctl
