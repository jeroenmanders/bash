#!/usr/bin/env bash

set -euo pipefail

before_init_dir="$(pwd)"
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

export LOG_LEVEL="INFO"
export REPO_DIR="$(git rev-parse --show-toplevel)"

SOURCE_SOURCED="${SOURCE_SOURCED-false}"

if [ "$SOURCE_SOURCED" == "true" ]; then
  log_debug "files under source/* already sourced." # only source scripts once
else
  bash_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for f in "$bash_dir"/source/*.sh; do
    # shellcheck source=/dev/null
    source "$f"
  done
  SOURCE_SOURCED="true"
fi

if [ -f "$bash_dir/settings.yml" ]; then
  [[ -z "${TERRAFORM_VERSION-}" ]] && get_var TERRAFORM_VERSION "$bash_dir/settings.yml" ".versions .terraform" "1.1.5"
  [[ -z "${PACKER_VERSION-}" ]] && get_var PACKER_VERSION "$bash_dir/settings.yml" ".versions .packer" "1.7.8"
else
  export TERRAFORM_VERSION="${TERRAFORM_VERSION-"1.1.5"}"
  export PACKER_VERSION="${PACKER_VERSION-"1.7.8"}"
fi

# The following resources can be installed using scripts under $REPO_DIR/utils
export TERRAFORM="$REPO_DIR/local-resources/bin/terraform-$TERRAFORM_VERSION"
export PACKER="$REPO_DIR/local-resources/bin/packer-$PACKER_VERSION"

cd "$before_init_dir" || exit 1
