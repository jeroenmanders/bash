#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

get_var "HELM_CHART" "$VAULT_CONFIG_FILE" ".vault .helm .chart .name" ""
get_var "HELM_CHART_VERSION" "$VAULT_CONFIG_FILE" ".vault .helm .chart .version" ""
get_var "HA_ENABLED" "$VAULT_CONFIG_FILE" ".vault .ha .enabled" ""
get_var "HA_REPLICAS" "$VAULT_CONFIG_FILE" ".vault .ha .replicas" ""

function _run_on_worker() {
  local hostname="$(hostname)"
  local mount_root="/mnt/disks"

  if [ -d "$mount_root/vault" ]; then
    echo "Directory $mount_root/vault already exists. Assuming mounts are already configured correctly."
  else
    cd
    mkdir -p data
    mkdir -p data/vault
    sudo mkdir -p "$mount_root/vault"
    sudo mount --bind "$(pwd)/data/vault" "$mount_root/vault"
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

function configure_helm() {
  log_info "Configuring Helm."
  helm repo add hashicorp https://helm.releases.hashicorp.com
  helm search repo hashicorp/vault
}

function run_yaml_files() {
  log_info "Processing templates."
  local VAULT_CA="$(< certificates-local/"$SERVICE_NAME".ca base64 -w0)"
  local VAULT_CRT="$(< certificates-local/"$SERVICE_NAME".crt base64 -w0)"
  local VAULT_KEY="$(< certificates-local/"$SERVICE_NAME".key base64 -w0)"

  cat templates/tls-secret.yaml | \
      yq '.data ."vault.ca" = "'"$VAULT_CA"'" | .data ."vault.crt" = "'"$VAULT_CRT"'" | .data ."vault.key" = "'"$VAULT_KEY"'"' \
      > yaml/tls-secret.local.yaml

  log_info "Applying yaml files."
  cat yaml/*.yaml | envsubst | kubectl apply -n "$VAULT_NAMESPACE" -f -
}

function install_vault() {
  log_info "Installing Vault."
  helm install vault "$HELM_CHART" --namespace "$VAULT_NAMESPACE" -f helm/values/vault.yaml
}

if [ ! "$(which helm)" ]; then
  log_fatal "Helm is not installed. The /utils-folder in this repository contains a script for this"
fi

function init_vault() {
  kubectl exec -it vault-0 -- sh
  export VAULT_CACERT=/vault/userconfig/vault-tls/vault.ca
  # Initialize
  vault operator init

  vault unseal ...

  exit

  kubectl exec -it vault-1 -- sh
  export VAULT_CACERT=/vault/userconfig/vault-tls/vault.ca
  export CA_CERT=`cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
  vault operator raft join -leader-ca-cert="$CA_CERT" https://vault-0.vault-internal:8200

  kubectl exec -it vault-2 -- sh
    export VAULT_CACERT=/vault/userconfig/vault-tls/vault.ca
    export CA_CERT=`cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
    vault operator raft join -leader-ca-cert="$CA_CERT" https://vault-0.vault-internal:8200
}

prepare_workers
configure_helm
generate_certificate
run_yaml_files
install_vault

#vault operator unseal kP7oAgACmYdGhOKJnHZ9AAGPOP6mkbpPJjnv4jTUc4dp
#vault operator unseal A4LhuTEYNgen3w1s6ccN5btfWdylY5Q9EVwOKlUwMy/W
#vault operator unseal xgeLUeKoZLzLsbZUmjydZnxW2i+dpo0mdkJz0aJtRDPE
#
#/ $ vault operator init
#Unseal Key 1: qiM/Hmja4HM9nBts2X/u/9G0efMUfizt9hPhxbmcVDhP
#Unseal Key 2: kP7oAgACmYdGhOKJnHZ9AAGPOP6mkbpPJjnv4jTUc4dp
#Unseal Key 3: A4LhuTEYNgen3w1s6ccN5btfWdylY5Q9EVwOKlUwMy/W
#Unseal Key 4: xgeLUeKoZLzLsbZUmjydZnxW2i+dpo0mdkJz0aJtRDPE
#Unseal Key 5: QJcdmpEcB6XxkWXrorz2ZaEIqwmLbmtzXGgu2zAltQ2v
#
# export VAULT_TOKEN="s.IDnJWmimJfIGl1hmQ86HMxkm"
