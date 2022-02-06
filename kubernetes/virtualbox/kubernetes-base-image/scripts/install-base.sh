#!/usr/bin/env bash

exec > >(tee -a /var/log/base-image-install.log | logger -s -t base-image-install) 2>&1

. ./env.sh;

install_base;
