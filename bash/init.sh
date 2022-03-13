#!/usr/bin/env bash

set -euo pipefail

org_dir="$(pwd)"
init_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$init_dir" || exit 1

export LOG_LEVEL="INFO"
export REPO_DIR="$(git rev-parse --show-toplevel)"
export SHARED_REPO_DIR="$REPO_DIR"
cd "$org_dir" || exit 1

SOURCE_SOURCED="${SOURCE_SOURCED-false}"

if [ "$SOURCE_SOURCED" == "true" ]; then
  log_debug "files under source/* already sourced." # only source scripts once
else
  for f in "$init_dir"/source/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
  SOURCE_SOURCED="true"
fi

if [ -f "$init_dir/settings.yml" ]; then
  [[ -z "${TERRAFORM_VERSION-}" ]] && get_var TERRAFORM_VERSION "$init_dir/settings.yml" ".versions .terraform" "1.1.5"
  [[ -z "${PACKER_VERSION-}" ]] && get_var PACKER_VERSION "$init_dir/settings.yml" ".versions .packer" "1.7.8"
else
  export TERRAFORM_VERSION="${TERRAFORM_VERSION-"1.1.5"}"
  export PACKER_VERSION="${PACKER_VERSION-"1.7.8"}"
fi

# The following resources can be installed using scripts under $REPO_DIR/utils
export TERRAFORM="$REPO_DIR/local-resources/bin/terraform-$TERRAFORM_VERSION"
export PACKER="$REPO_DIR/local-resources/bin/packer-$PACKER_VERSION"
