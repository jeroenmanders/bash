#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(git rev-parse --show-toplevel)"

. "$REPO_DIR/bash/init.sh"

[[ ! -d "$REPO_DIR/local-resources/bin" ]] && mkdir "$REPO_DIR/local-resources/bin"
