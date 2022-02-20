#!/usr/bin/env bash

set -euo pipefail

. ../shared/env.sh

export SERVICE_NAME="$REGISTRY_NAME"
export SERVICE_NAMESPACE="$REGISTRY_NAMESPACE"
