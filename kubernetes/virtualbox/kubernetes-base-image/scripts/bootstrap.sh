#!/usr/bin/env bash

# Bootstrap the controller or a worker.
# This script is automatically started during boot from kube-bootstrap.service.

exec > >(tee -a /var/log/kube-bootstrap.log | logger -s -t kube-bootstrap) 2>&1

. ./vars.local
. ./env.sh

get_guest_properties

if [ "$HOST_TYPE" == "controller" ]; then
  get_guest_property "cluster-name"
  init_cluster "$LAST_VALUE"

  JOIN_COMMAND="$(kubeadm token create --print-join-command)"

  # Reading guestproperties only works for string up-to 150 characters ...
  join_command_1="${JOIN_COMMAND:0:150}"
  join_command_2="${JOIN_COMMAND:150}"
  echo "Setting join-command-1 guest property to: '$join_command_1'."
  VBoxControl --nologo guestproperty set "join-command-1" "$join_command_1"

  echo "Setting join-command-2 guest property to: '$join_command_2'."
  VBoxControl --nologo guestproperty set "join-command-2" "$join_command_2"

elif [ "$HOST_TYPE" == "worker" ]; then
  join_cluster
else
  echo "!!! ERROR: host type '$HOST_TYPE' not recognized!"
  exit 1
fi

function mount_host_share() {
  local host_ip="$1"
  local mount_point="$2"
  #sudo apt-get update

  sudo mkdir -p /mnt/host
  sudo mount -t nfs4 "$host_ip":"$mount_point" /mnt/host
  echo "$host_ip:$mount_point /mnt/host   nfs4    defaults   0   0" | sudo tee -a /etc/fstab
}

get_guest_property "host-ip"
host_ip="$LAST_VALUE"
get_guest_property "mount-point"
mount_point="$LAST_VALUE"

if [ -z "$host_ip" -o -z "$mount_point" ]; then
  echo "Property 'host-ip' or 'mount-point' not set so not mounting a host share"
else
  mount_host_share "$host_ip" "$mount_point"
fi

systemctl disable kube-bootstrap.service
