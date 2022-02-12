#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function setup_nfs_server() {
#  if [ "$(which "yq")" ]; then
#    log_info "'yq' is already installed."
#    return
#  fi

  if [ -f "/proc/fs/nfsd/versions" ]; then
    log_warn "NFS server seems to be installed already because '/proc/fs/nfsd/versions' exists. Aborting."
    exit 1
  fi

  log_info "Installing NFS server."
  sudo apt-get update
  sudo apt-get install -y nfs-kernel-server
}


setup_nfs_server
