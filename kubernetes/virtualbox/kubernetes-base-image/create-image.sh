#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir"

REPO_DIR="$(git rev-parse --show-toplevel)"
. "$REPO_DIR/kubernetes/env.sh"

VBOX_DIR="$REPO_DIR/local-resources/virtualbox"

[[ -f ~/.vimrc ]] && cp ~/.vimrc scripts/vimrc.temp
[[ ! -d "$VBOX_DIR" ]] && mkdir "$VBOX_DIR"
[[ ! -d "$VBOX_DIR/iso" ]] && mkdir "$VBOX_DIR/iso"

[[ -d "$VBOX_DIR/kubernetes-base" ]] && rm -Rf "$VBOX_DIR/kubernetes-base"

log_info "Starting Packer build."
$PACKER build -var "os_username=$OS_USERNAME" \
  -var "os_user_id=$OS_USER_ID" \
  -var "os_user_pub_key=$OS_USER_PUB_KEY" \
  -var "os_group_id=$OS_GROUP_ID" \
  .

[[ -f scripts/vimrc.temp ]] && rm scripts/vimrc.temp
