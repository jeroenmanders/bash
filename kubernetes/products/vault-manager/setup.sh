#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

get_var "HELM_CHART" "$VAULT_CONFIG_FILE" ".vault .helm .chart .name" ""
get_var "HELM_CHART_VERSION" "$VAULT_CONFIG_FILE" ".vault .helm .chart .version" ""
get_var "HA_ENABLED" "$VAULT_CONFIG_FILE" ".vault .ha .enabled" ""
get_var "HA_REPLICAS" "$VAULT_CONFIG_FILE" ".vault .ha .replicas" ""

function init_vault() {
  kubectl exec -it vault-0 -- sh
  VAULT_CACERT="/etc/ssl/certs/vault.ca"

  log_info "Initializing the Vault cluster in namespace '$SERVICE_NAMESPACE'."
  kubectl exec -it vault-0 -- vault status --format=json status
}

function init_vault() {
  local POD_IPS="$(kubectl get pods --selector=app.kubernetes.io/instance=vault,app.kubernetes.io/name=vault -o jsonpath='{.items[*] .status .podIP}')"
  local mgr="$(kubectl get pod --selector=app=vault-manager -o jsonpath='{.items[0] .metadata .name}')"

  kubectl exec -it $mgr -- sh
  export VAULT_CACERT=/vault/userconfig/vault-tls/vault.ca
  nslookup vault.vault-dev.svc.cluster.local
  VAULT_0=vault-0.vault-dev
  VAULT_0_IP="$(echo "$POD_IPS" | cut -d ' ' -f 1)"
  VAULT_1=vault-1.vault-dev
  VAULT_1_IP="$(echo "$POD_IPS" | cut -d ' ' -f 2)"
  VAULT_2=vault-2.vault-dev
  VAULT_2_IP="$(echo "$POD_IPS" | cut -d ' ' -f 3)"

  echo "$VAULT_0_IP $VAULT_0" >> /etc/hosts
  echo "$VAULT_1_IP $VAULT_1" >> /etc/hosts
  echo "$VAULT_2_IP $VAULT_2" >> /etc/hosts

  export VAULT_ADDR=https://$VAULT_0:8200
  # Initialize
  vault operator init -format=json

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
