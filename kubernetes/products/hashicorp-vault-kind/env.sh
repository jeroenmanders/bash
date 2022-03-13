#!/usr/bin/env bash

set -euo pipefail

. ../shared/env.sh

get_var "VAULT_NAMESPACE" "$VAULT_CONFIG_FILE" ".vault .namespace .name" ""

export SERVICE_NAME="vault"
export SERVICE_NAMESPACE="$VAULT_NAMESPACE"
