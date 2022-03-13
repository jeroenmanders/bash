#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function install_go() {
  local VERSION="1.17.7"
  local filename="go${VERSION}.linux-amd64.tar.gz"

  log_info "Downloading $filename"
  curl -OLs "https://go.dev/dl/$filename"
  log_info "Installing Go $VERSION"
  sudo tar -C /usr/local -xzf "$filename"
  rm "$filename"
  log_warn "Add the following to your profile:"
  echo 'export PATH=$PATH:/usr/local/go/bin'

}

install_go

