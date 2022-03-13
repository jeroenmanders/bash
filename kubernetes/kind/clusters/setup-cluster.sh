#!/usr/bin/env bash

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/env.sh"

setup_cluster "kube-local" "kind-kube-local.yaml"
