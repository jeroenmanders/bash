#!/usr/bin/env bash

set -euo pipefail

function load_gcp_vars() {
  local VAR_FILE="$SHARED_REPO_DIR/data.local/cloud/gcp.yaml"
  unset GCP_ORGS
  if [ ! -f "$VAR_FILE" ]; then
    log_error "File not found: $VAR_FILE"
    return 1
  fi

  get_var "GCP_ORGS" "$VAR_FILE" ".organizations" ""
  for org in $(echo "$GCP_ORGS" | yq -o json | jq -cr '.[]'); do
    local name="$(echo "$org" | jq -r '.name')"
    local org_id="$(echo "$org" | jq -r '."organization-id"')"
    local dir_customer_id="$(echo "$org" | jq -r '."directory-customer-id"')"
    local billing_account="$(echo "$org" | jq -r '."billing-account"')"
    local var_prefix="$(echo "$org" | jq -r '."var-prefix"')"

    export "${var_prefix}_ORG_ID"="$org_id"
    export "${var_prefix}_DIR_CUSTOMER_ID"="$dir_customer_id"
    export "${var_prefix}_BILLING_ACCOUNT"="$billing_account"
  done
  unset GCP_ORGS
}
