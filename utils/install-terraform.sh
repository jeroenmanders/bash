#!/usr/bin/env bash

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$this_dir" || exit 1

. ./env.sh

function ensure_terraform() {
  # TERRAFORM_VERSION is set in bash/init.sh
  local zip_file="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    local url="https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/$zip_file"

  export TERRAFORM="$REPO_DIR/local-resources/bin/terraform-$TERRAFORM_VERSION"
  [[ -f "$TERRAFORM" ]] && log_warn "$TERRAFORM already exists. Using it instead of downloading a new binary." && return

  echo "Downloading $zip_file."
  curl -sLo "$zip_file" "$url"

  echo "Extracting archive."
  unzip "$zip_file"
  mv terraform "$TERRAFORM"
  rm -Rf "$zip_file"

  echo "Using Terraform:"
  $TERRAFORM --version
}

ensure_terraform
