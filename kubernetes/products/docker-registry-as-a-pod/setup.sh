#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function _run_on_worker() {
  local mount_root="/mnt/disks"
  local dir_name="docker-registry"
  if [ -d "$mount_root/$dir_name" ]; then
    echo "Directory '$mount_root/$dir_name' already exists. Assuming mounts are already configured correctly."
  else
    cd
    mkdir -p data
    mkdir -p "data/$dir_name"
    sudo mkdir -p "$mount_root/$dir_name"
    sudo mount --bind "$(pwd)/data/$dir_name" "$mount_root/$dir_name"
  fi
}

function prepare_workers() {
  for i in $(seq 1 "$WORKERS"); do
    get_vm_ip "$WORKER-$i"

    log_info "Preparing worker $WORKER-$i"

    ssh "$OS_USERNAME"@"$IP" <<EOF
        $(typeset -f _run_on_worker)
        _run_on_worker
EOF
  done
}

function run_yamls() {
  log_info "Applying yaml files."
  local DOCKER_REGISTRY_CRT="$(cat "certificates-local/$REGISTRY_NAME.crt")"
  local DOCKER_REGISTRY_KEY="$(cat "certificates-local/$REGISTRY_NAME.key")"
  cat templates/certificate-cm.template.yaml | \
    yq '.data ."docker-registry.crt" = "'"$DOCKER_REGISTRY_CRT"'" | .data ."docker-registry.key" = "'"$DOCKER_REGISTRY_KEY"'"' \
    > yaml/certificate-cm.local.yaml

  cat yaml/*.yaml | envsubst | kubectl apply -n "$REGISTRY_NAMESPACE" -f -

}

#function get_docker_registry_host_and_port() {
#  get_REGISTRY_NAME_and_port ""
#}
#
#function get_REGISTRY_NAME_and_port() {
#  local namespace="$1"
#  local REGISTRY_NAME="$2"
#
#  [[ -z "$namespace" ]] && log_fatal "First argument to get_docker_registry_host_and_port should be a namespace name."
#  [[ -z "$REGISTRY_NAME" ]] && log_fatal "First argument to get_docker_registry_host_and_port should be a namespace name."
#}

function get_cluster_config() {
  get_random_node_internal_ip
  export NODE_IP="$LAST_VALUE"

  log_info "Retrieving node port of service $REGISTRY_NAME."
  export DOCKER_REGISTRY_NODEPORT="$(kubectl get svc "$REGISTRY_NAME" -n "$REGISTRY_NAMESPACE" -o=jsonpath='{.spec.ports[0].nodePort}')"

  local line="$NODE_IP $REGISTRY_HOSTNAME"

  if grep " $REGISTRY_HOSTNAME$" /etc/hosts; then
    echo "Replacing line for '$REGISTRY_HOSTNAME' with '$line'."
    sudo sed -i "s/.* $REGISTRY_HOSTNAME$/$line/g" /etc/hosts
  else
    log_info "Adding '$line' to /etc/hosts."
    echo "$line" | sudo tee -a /etc/hosts
  fi
  echo "======== -------- ======== "
  echo " Login to Docker with: "
  echo "      sudo docker login $REGISTRY_HOSTNAME:$DOCKER_REGISTRY_NODEPORT"
  echo
  echo "======== IMPORTANT ======= "
  echo "If you use Docker on this machine, then you need to restart the daemon so that it uses the new cert."
  echo "    sudo systemctl restart docker.service"
  echo "======== --------- ======= "
}

prepare_workers
generate_certificate
run_yamls
get_cluster_config
