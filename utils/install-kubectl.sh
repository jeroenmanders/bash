#!/usr/bin/env bash

. ./env.sh

KUBECTL_VERSION="v1.23.0"

function ensure_kubectl() {
  log_info "Installing kubectl $KUBECTL_VERSION."
  curl -LO https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl
  curl -LO "https://dl.k8s.io/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
  echo "$(<kubectl.sha256) kubectl" | sha256sum --check
  rm kubectl.sha256
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
}

ensure_kubectl
