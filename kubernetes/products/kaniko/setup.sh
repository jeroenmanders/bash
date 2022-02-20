#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

function run_yamls() {
  log_info "Applying yaml files."
  local DOCKER_JSON_BASE64="$(< templates/local-docker-config.json envsubst | base64 -w0)"

  cat templates/docker-secret.yaml | \
    yq '.data .".dockerconfigjson" = "'"$DOCKER_JSON_BASE64"'"' \
    > yaml/docker-secret.local.yaml

  cat yaml/*.yaml | envsubst | kubectl apply -n "$SERVICE_NAMESPACE" -f -


}

run_yamls
