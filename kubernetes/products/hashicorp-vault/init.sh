#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function init_vault_in_manager() {
  VAULT_CACERT="/etc/ssl/certs/vault.ca"
  VAULT_ADDR=
  log_info "Initializing the Vault cluster in namespace '$SERVICE_NAMESPACE'."
  kubectl exec -it vault-0 -- vault status --format=json status
  #kubectl exec --stdin=true --tty=true vault-0 -- -format=json > "init-output.json";

}

delete_resources
