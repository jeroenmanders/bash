#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../env.sh"

export CLUSTER_MODE="KIND"
export KIND_SETTINGS_DIR="$KIND_DIR/settings"
export PRODUCTS_CONFIG_FILE="$KIND_SETTINGS_DIR/products.local.yaml"
