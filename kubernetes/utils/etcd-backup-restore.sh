#!/usr/bin/env bash

# This should be run on the controller currently

# See https://ystatit.medium.com/backup-and-restore-kubernetes-etcd-on-the-same-control-plane-node-20f4e78803cb

export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_API=3

function get_etcd_pod() {
  export ETCD_POD="$(kubectl get pods -n kube-system --selector='component=etcd,tier=control-plane' --output=jsonpath={.items..metadata.name})"
}

function get_etcd_url() {
  get_etcd_pod
  export ETCD_URL="$(kubectl get pod "$ETCD_POD" -n kube-system -o=jsonpath='{.spec.containers[0].command}' | jq -r '. []' | grep -e '^--advertise-client-urls=' | cut -d '=' -f 2)"
}

function backup_etcd() {
  # apt install etcd-client
  get_etcd_url
  etcdctl snapshot save /tmp/etcdBackup.db \
    --endpoints="$ETCD_URL" \
    --cacert="$ETCDCTL_CACERT" \
    --cert=ETCDCTL_CERT \
    --key=ETCDCTL_KEY

  etcdctl --write-out=table snapshot status /tmp/etcdBackup.db
}

function move_static_pod_manifests() {
  export TMP_MANIFESTS_BACKUP="/opt/backups/static-pod-manifests/$(date +%Y%m%d%H%M)"
  mkdir -p "$TMP_MANIFESTS_BACKUP"
  mv /etc/kubernetes/manifests/*.yaml "$TMP_MANIFESTS_BACKUP"
}

function move_etcd_data() {
  export BACKUP="/opt/backups/etcd_data_dir/$(date +%Y%m%d%H%M)"
  mkdir -p "$BACKUP"
  mv /var/lib/etcd/member "$BACKUP"
}

function restore_static_pod_manifests() {
  cp "$TMP_MANIFESTS_BACKUP"/* "/etc/kubernetes/manifests/"
}

function restore_etcd() {
  get_etcd_url
  move_static_pod_manifests

  # wait for the static pods to stop (now using sleep which is not good)
  #  check for the pods using `crictl pods`
  sleep 10
  move_etcd_data # backup the current etcd data

  restore_static_pod_manifests

  cd ~ || log_fatal "Unable to CD into the home directory."
  etcdctl snapshot restore /tmp/etcdBackup.db # this creates `default.etcd/member`
  mv default.etcd/member /var/lib/etcd/
  restore_static_pod_manifests
  rm -Rf default.etcd
}
