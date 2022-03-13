#!/usr/bin/env bash

echo "Restoring nfs mount"

id

host_ip="192.168.1.204"
mkdir -p /opt/nfs/
mount -o vers=4,resvport,rw -t nfs "$host_ip":/ /opt/nfs/host-share/

dss
