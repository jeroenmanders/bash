#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/../../env.sh"

if [ ! "$(which cmctl)" ]; then
  log_fatal "Certificate Manager CLI 'cmctl' is not installed. You can install it using '$REPO_DIR/utils/install-cmctl.sh'."
fi
