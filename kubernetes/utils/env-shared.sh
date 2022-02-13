#!/usr/bin/env bash

# This file exists so that these functions can be made available through a bash_profile
#   without sourcing all Bash utilities

function configure_kubernetes_cli() {
  source <(kubectl completion bash)
  alias k=kubectl
  complete -F __start_kubectl k
}

function get_vm_id() {
  local vm_name="$1"
  export VM_ID="$(vboxmanage list runningvms | grep '^"'"$vm_name"'"' | cut -d ' ' -f 2)"
  export VM_ID="${VM_ID:1:${#VM_ID}-2}" # remove accolades
  echo "VM_ID of $vm_name: $VM_ID"
}

function get_host_only_MAC() {
  local vm_id="$1"
  local part1="$(vboxmanage showvminfo --details "$vm_id" | grep -e '^NIC.*vboxnet0' | cut -d ',' -f 1)"
  export MAC="${part1##* }"
}

function get_vm_ip() {
  local vm_name="$1"
  get_vm_id "$vm_name"
  get_host_only_MAC "$VM_ID"
  export IP="$(vboxmanage dhcpserver findlease --interface vboxnet0 --mac-address="$MAC" | grep "^IP Address:" | cut -d ' ' -f 4)"
}

function conn_vm() {
  local vm_name="$1"
  get_vm_ip "$vm_name"

  echo "Connecting with $KUBE_OS_USERNAME@$IP"
  ssh "$KUBE_OS_USERNAME@$IP"
}

function conn_controller() {
  conn_vm kube-controller-1
}

function conn_worker() {
  conn_vm "kube-worker-$1"
}
