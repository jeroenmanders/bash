#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$this_dir/../shared/env.sh"

get_var "KANIKO_NAMESPACE" "$KANIKO_CONFIG_FILE" ".kaniko .namespace .name" ""

export SERVICE_NAME="kaniko"
export SERVICE_NAMESPACE="$KANIKO_NAMESPACE"
