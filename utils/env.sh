#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(git rev-parse --show-toplevel)"
BIN_DIR="$REPO_DIR/local-resources/bin"

. "$REPO_DIR/bash/init.sh"

[[ ! -d "$BIN_DIR" ]] && mkdir "$BIN_DIR" || :
