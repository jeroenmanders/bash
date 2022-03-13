#!/usr/bin/env bash

set -euo pipefail;

export username="$1";

[[ -z "$username" ]] && echo "Please provide the username as the first argument." && exit 1;

cd ~/workspace/kubernetes/utils

. ./add-cluster-user.sh;

create_kubernetes_user "$username";
