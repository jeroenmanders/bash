#!/usr/bin/env bash

set -euo pipefail

# Disabled the following because it hides `read`-commands. TODO: fix
# exec > >(sudo tee -a /var/log/kube-work.log | logger -s -t kube) 2>&1

_org_dir="$(pwd)"
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

REPO_DIR="$(git rev-parse --show-toplevel)"
. "$REPO_DIR"/bash/init.sh

export USER_HOME="$(eval echo ~)"

export VBOX_CONFIG_FILE="$REPO_DIR/kubernetes/settings/005-virtualbox.local.yaml"
export K8S_CONFIG_FILE="$REPO_DIR/kubernetes/settings/010-kubernetes.local.yaml"
export REGISTRY_CONFIG_FILE="$REPO_DIR/kubernetes/settings/050-registry.local.yaml"
export VAULT_CONFIG_FILE="$REPO_DIR/kubernetes/settings/100-vault.local.yaml"
export KANIKO_CONFIG_FILE="$REPO_DIR/kubernetes/settings/100-kaniko.local.yaml"

# Currently just one cluster can be configured.
get_var "VM_NAME_PREFIX" "$VBOX_CONFIG_FILE" ".virtualbox .vm-prefix" ""
get_var "AUTOSTART_VMS" "$VBOX_CONFIG_FILE" ".virtualbox .autostart-vms" "true"
get_var "OS_USERNAME" "$VBOX_CONFIG_FILE" ".virtualbox .os-user .name" ""
get_var "OS_USER_ID" "$VBOX_CONFIG_FILE" ".virtualbox .os-user .id" ""
get_var "OS_USER_PUB_KEY" "$VBOX_CONFIG_FILE" ".virtualbox .os-user .ssh-public-key" ""
get_var "OS_GROUP_ID" "$VBOX_CONFIG_FILE" ".virtualbox .os-user .group-id" ""

get_var "CLUSTER_NAME" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .name" "test"
get_var "WORKERS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .workers" "3"
get_var "MERGE_KUBECONFIGS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .merge-kubeconfigs" ""

export CONTROLLER="$VM_NAME_PREFIX-controller"
export WORKER="$VM_NAME_PREFIX-worker"

cd "$_org_dir" || exit 1
