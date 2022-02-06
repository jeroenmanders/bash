#!/usr/bin/env bash

set -euo pipefail;

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd "$this_dir";

. ../../../bash/init.sh;

VBOX_DIR="$REPO_DIR/local-resources/virtualbox";

[[ -f ~/.vimrc ]] && cp ~/.vimrc scripts/vimrc.temp;
[[ ! -d "$VBOX_DIR" ]] && mkdir "$VBOX_DIR";
[[ ! -d "$VBOX_DIR/iso" ]] && mkdir "$VBOX_DIR/iso";

[[ -d "$VBOX_DIR/kubernetes-base" ]] && rm -Rf "$VBOX_DIR/kubernetes-base";

log_info "Starting Packer build.";
$PACKER build .

[[ -f scripts/vimrc.temp ]] && rm scripts/vimrc.temp;
