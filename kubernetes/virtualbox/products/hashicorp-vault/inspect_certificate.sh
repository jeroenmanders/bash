#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ./env.sh

inspect_certificate "certificates-local/vault.key" \
                    "certificates-local/vault-server.csr" \
                    "certificates-local/vault.crt" \
