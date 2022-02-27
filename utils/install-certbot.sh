#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function install_certbot() {
  if [ "$ON_OSX" == "true" ]; then

  elif [ "$IS_DEBIAN" == "true" ]; then
    log_info "Installing Certbot on a Debian-like OS."
    sudo apt-add-repository ppa:certbot/certbot
    sudo apt install certbot
  else

  fi
}

install_certbot

