#!/usr/bin/env bash

this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd "$this_dir";

. ./env.sh;

remove_cluster;
