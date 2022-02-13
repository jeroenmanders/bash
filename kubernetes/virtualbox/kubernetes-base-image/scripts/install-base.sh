#!/usr/bin/env bash

exec > >(tee -a /var/log/base-image-install.log | logger -s -t base-image-install) 2>&1

export OS_USERNAME="${1:- }"
export OS_USER_ID="${2:- }"
export OS_USER_PUB_KEY="${3:- }"
export OS_GROUP_ID="${4:- }"

. ./env.sh

install_base
