#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir"

REPO_DIR="$(git rev-parse --show-toplevel)"
. $REPO_DIR/bash/init.sh

# Currently just one cluster can be configured.
#  Use something like the following to support multiple clusters:
#  '.kubernetes .clusters [] | select(.name-prefix == "kube") .main-user'
get_var "VM_NAME_PREFIX" "../settings.local.yml" ".kubernetes .clusters[0] .name-prefix" "";
get_var "OS_USERNAME" "../settings.local.yml" ".kubernetes  .clusters[0] .main-user" "";
get_var "AUTOSTART_VMS" "../settings.local.yml" ".virtualbox .autostart-vms" "true";
OVA_FILE="$REPO_DIR/local-resources/virtualbox/kubernetes-base/kubernetes-base.ovf"

CONTROLLER="$VM_NAME_PREFIX-controller"
WORKER="$VM_NAME_PREFIX-worker"

function configure_vbox_network() {
  if vboxmanage list hostonlyifs | grep -e '^VBoxNetworkName:.*HostInterfaceNetworking-vboxnet0' >/dev/null; then
    log_info "Host only network 'HostInterfaceNetworking-vboxnet0' is already configured. Not modifying it."
    return
  fi
  local prefix=".virtualbox .dhcp .vboxnet0"
  get_var "_TMP_IP" "../settings.local.yml" "$prefix .ip" "192.168.56.1"
  get_var "_TMP_NETMASK" "../settings.local.yml" "$prefix .netmask" "192.168.56.1"
  get_var "_TMP_LOWERIP" "../settings.local.yml" "$prefix .ip" "192.168.56.1"
  get_var "_TMP_UPPERIP" "../settings.local.yml" "$prefix .ip" "192.168.56.1"

  log_info "Configuring Virtualbox host only network vboxnet0."
  vboxmanage hostonlyif create
  vboxmanage hostonlyif ipconfig vboxnet0 --ip "$_TMP_IP"
  vboxmanage dhcpserver add --ifname vboxnet0 --ip "$_TMP_IP" --netmask "$_TMP_NETMASK" --lowerip "$_TMP_LOWERIP" --upperip "$_TMP_UPPERIP"
  vboxmanage dhcpserver modify --ifname vboxnet0 --enable
}

function install_extensions() {
  curl -o vbox-extpack https://download.virtualbox.org/virtualbox/6.1.32/Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack
  echo "y" | vboxmanage extpack install ./vbox-extpack
}

function setup_cluster() {
  # We're using 2 join-commands because the maximum (reading) length of guest properties is 150 characters
  #   And alternative would be to generate a file and copy it to the machine (SMB or something like the following)
  # VBoxManage guestcontrol "kube-controller-1" run /bin/sh --username $OS_USERNAME --verbose --wait-stdout \
  #     --wait-stderr -- -c "echo '$JOIN_COMMAND' > /tmp/join-command.txt"
  local join_command_1=""
  local join_command_2=""

  create_vm "$CONTROLLER-1" controller
  create_vm "$WORKER-1" worker "join-command"
  create_vm "$WORKER-2" worker "join-command"

  local started_at_second=$(date +%s)
  local fail_at_second=$(expr $started_at_second + 900) # timeout after 15 minutes
  echo -e "Waiting for controller setup ."
  while [ "$join_command_2" == "" ]; do
    local join_command_with_value="$(vboxmanage guestproperty get $CONTROLLER-1 join-command-2)"
    local current_second=$(date +%s)
    if [ $current_second -gt $fail_at_second ]; then
      log_info "Timeout waiting for the cluster to get initialized. Aborting."
      exit 1
    fi
    if [ -n "$join_command_with_value" ]; then
      join_command_2="${join_command_with_value#"Value: "}"
      join_command_with_value="$(vboxmanage guestproperty get $CONTROLLER-1 join-command-1)"
      join_command_1="${join_command_with_value#"Value: "}"
    fi
    sleep 5
  done

  log_info "Setting join-command-1 for worker machines to '$join_command_1'"
  log_info "Setting join-command-2 for worker machines to '$join_command_2'"

  vboxmanage guestproperty set $WORKER-1 join-command-1 "$join_command_1"
  vboxmanage guestproperty set $WORKER-1 join-command-2 "$join_command_2"
  vboxmanage guestproperty set $WORKER-2 join-command-1 "$join_command_1"
  vboxmanage guestproperty set $WORKER-2 join-command-2 "$join_command_2"
}

function create_vm() {
  local vm_name="$1";
  local host_type="$2";

  log_info "Importing $OVA_FILE for $vm_name.";
  vboxmanage import $OVA_FILE --vsys 0 --vmname $vm_name;

  log_info "Adding second adapter.".
  vboxmanage modifyvm $vm_name --nic2 hostonly --hostonlyadapter2 vboxnet0;

  if [ "$AUTOSTART_VMS" == "true" ]; then
    log_info "Enabling autostart";
    vboxmanage modifyvm $vm_name --autostart-enabled on;
  else
    log_info "Not enabled autostart because AUTOSTART_VMS is '$AUTOSTART_VMS'.";
  fi;

  log_info "Setting guest host-name and type.";
  vboxmanage guestproperty set $vm_name host-name "$vm_name";
  vboxmanage guestproperty set $vm_name host-type $host_type;

  log_info "Starting VM $vm_name.";
  vboxmanage startvm $vm_name --type=headless;
}

function remove_cluster() {
  read -p "Are you sure you want to remove the virtual machines? [y/N]: " answer
  [[ "$answer" != "y" ]] && log_info "Answer was not 'y' so quitting." && exit 1
  remove_vm $CONTROLLER-1
  remove_vm $WORKER-1
  remove_vm $WORKER-2
}

function remove_vm() {
  local vm_name="$1"
  vboxmanage controlvm $vm_name poweroff
  vboxmanage unregistervm --delete $vm_name
}
