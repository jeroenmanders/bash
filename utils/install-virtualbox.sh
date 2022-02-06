#!/usr/bin/env bash

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd "$this_dir";

. ./env.sh;

function install_virtualbox() {
  log_info "Downloading Virtualbox for Ubuntu 19+.";
  curl -so virtualbox.deb https://download.virtualbox.org/virtualbox/6.1.32/virtualbox-6.1_6.1.32-149290~Ubuntu~eoan_amd64.deb
  curl -sO https://www.virtualbox.org/download/oracle_vbox_2016.asc;

  log_info "Downloading VirtualBox extension pack.";
  curl -sO https://download.virtualbox.org/virtualbox/6.1.32/Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack

  echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian xenial contrib" | sudo tee -a /etc/apt/sources.list

  sudo apt-key add oracle_vbox_2016.asc;
  sudo apt-get update;
  sudo apt-get install -y ./virtualbox.deb;

  sudo vboxmanage extpack install ./Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack

  rm virtualbox.deb oracle_vbox_2016.asc Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack;
}

install_virtualbox;
