#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

# . ./profile.sh
. ./env.sh

create_kubernetes_user "$@"
