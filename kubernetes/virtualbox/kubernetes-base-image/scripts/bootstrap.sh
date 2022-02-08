#!/usr/bin/env bash

# Bootstrap the controller or a worker.
# This script is automatically started during boot from kube-bootstrap.service.

exec > >(tee -a /var/log/kube-bootstrap.log | logger -s -t kube-bootstrap) 2>&1

. ./vars.local
. ./env.sh

get_guest_properties

if [ "$HOST_TYPE" == "controller" ]; then
  init_cluster
  #export KUBECONFIG=/etc/kubernetes/admin.conf # kubeconfig is under ~/.kube already
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

systemctl disable kube-bootstrap.service
