#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function install_virtualbox() {
  log_info "Downloading Virtualbox for Ubuntu 19+."
  curl -so virtualbox.deb https://download.virtualbox.org/virtualbox/6.1.32/virtualbox-6.1_6.1.32-149290~Ubuntu~eoan_amd64.deb
  curl -sO https://www.virtualbox.org/download/oracle_vbox_2016.asc

  log_info "Downloading VirtualBox extension pack."
  curl -sO https://download.virtualbox.org/virtualbox/6.1.32/Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack

  echo "deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian xenial contrib" | sudo tee -a /etc/apt/sources.list

  sudo apt-key add oracle_vbox_2016.asc
  sudo apt-get update
  sudo apt-get install -y ./virtualbox.deb

  sudo vboxmanage extpack install ./Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack

  rm virtualbox.deb oracle_vbox_2016.asc Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack
}

function configure_virtualbox() {
 log_info "Configuring auto-start";
 cat >> /etc/default/virtualbox << EOF
VBOXAUTOSTART_DB=/etc/vbox
VBOXAUTOSTART_CONFIG=/etc/vbox/autostartvm.cfg
EOF
 mkdir -p /etc/vbox;
 cat >> /etc/vbox/autostartvm.cfg << EOF
default_policy = deny

jeroen = {
    allow = true
    startup_delay = 10
}
EOF

  usermod -aG vboxusers jeroen
  chgrp vboxusers /etc/vbox
  chmod g+w /etc/vbox
  chmod +t /etc/vbox

  vboxmanage setproperty autostartdbpath /etc/vbox/;

}

install_virtualbox;

log_info "Adjust and run the code in function 'configure_virtualbox' to automate VBox startup.";
