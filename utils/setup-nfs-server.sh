#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function ensure_yq() {
  if [ "$(which "yq")" ]; then
    log_info "'yq' is already installed."
    return
  fi

  log_info "Installing 'yq'."
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod a+x /usr/local/bin/yq
}

function install_utils() {
  ensure_yq
  sudo apt-get update
  sudo apt-get install -y jq git
}

install_utils
