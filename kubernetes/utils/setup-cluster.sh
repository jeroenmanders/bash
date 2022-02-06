#!/usr/bin/env bash

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$this_dir" || exit 1

. ./env.sh

configure_vbox_network
setup_cluster
