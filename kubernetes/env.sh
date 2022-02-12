#!/usr/bin/env bash

_org_dir="$(pwd)"
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir"

REPO_DIR="$(git rev-parse --show-toplevel)"
. "$REPO_DIR"/bash/init.sh

export VBOX_CONFIG_FILE="$REPO_DIR/kubernetes/settings/005-virtualbox.local.yaml"
export K8S_CONFIG_FILE="$REPO_DIR/kubernetes/settings/010-kubernetes.local.yaml"
export VAULT_CONFIG_FILE="$REPO_DIR/kubernetes/settings/100-vault.local.yaml"

# Currently just one cluster can be configured.
get_var "VM_NAME_PREFIX" "$VBOX_CONFIG_FILE" ".virtualbox .vm-prefix" ""
get_var "AUTOSTART_VMS" "$VBOX_CONFIG_FILE" ".virtualbox .autostart-vms" "true"

get_var "CLUSTER_NAME" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .name" "test"
get_var "WORKERS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .workers" "3"
get_var "OS_USERNAME" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .os-user .name" ""
get_var "MERGE_KUBECONFIGS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .merge-kubeconfigs" ""

CONTROLLER="$VM_NAME_PREFIX-controller"
WORKER="$VM_NAME_PREFIX-worker"

cd "$_org_dir"
