#!/usr/bin/env bash

set -euo pipefail

VERSION=1.22.0
export DEBIAN_FRONTEND=noninteractive

function get_guest_property() {
  local name="$1"
  echo "Getting guest property '$name'"
  local with_value="$(VBoxControl --nologo guestproperty get "$name")"

  if [[ "$with_value" != "Value: "* ]]; then
    echo "Guest property '$name' not found."
    export LAST_VALUE=""
    return
  fi

  export LAST_VALUE="${with_value#"Value: "}"
  echo "Value: '$LAST_VALUE'"
}

function get_guest_properties() {
  get_guest_property "host-name"
  export HOST_NAME="$LAST_VALUE"
  echo "--- HOST_NAME = $HOST_NAME"
  get_guest_property "host-type"
  export HOST_TYPE="$LAST_VALUE"
}

function install_base() {
  echo "---- STARTING KUBERNETES BASE ----"
  cat <<EOF | sudo tee /etc/modules-load.d/containerd.config
overlay
br_netfilter
EOF

  sudo modprobe overlay
  sudo modprobe br_netfilter

  cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

  cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

  sudo sysctl --system
  sudo apt-get update
  sudo apt-get -y install curl apt-transport-https gnupg2 net-tools apt-transport-https jq containerd etcd-client nfs-common

  echo "Installing 'yq'."
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod a+x /usr/local/bin/yq

  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml

  sudo systemctl restart containerd

  # Kubernetes requires that swap is turned off
  sudo swapoff -a

  # Ensure swap is off after a restart
  sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

  cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
    deb https://packages.cloud.google.com/apt/ kubernetes-xenial main
EOF
  sudo apt-get update
  sudo apt-get install -y kubelet=$VERSION-00 kubeadm=$VERSION-00 kubectl=$VERSION-00
  sudo apt-mark hold kubelet kubeadm kubectl

  kubeadm config images pull
  configure_network
  create_os_user
  cp vimrc.temp /root/.vimrc

  install_guest_additions
  prepare_startup_script
  prepare_for_template

}

function prepare_startup_script() {
  echo "Configuring bootstrap service."
  cp kube-bootstrap.service /etc/systemd/system/kube-bootstrap.service
  systemctl daemon-reload
  systemctl enable kube-bootstrap.service
}

function configure_network() {
  echo "Ubuntu doesn't detect the host-only network interface automatically, so adding it here. TODO: can't this be done in a proper way?"
  cat >>/etc/netplan/01-netcfg.yaml <<EOF

    enp0s8:
      addresses: []
      dhcp4: true
      optional: true
EOF
}

function prepare_for_template() {
  echo "Cleaning system"
  truncate -s0 /etc/hostname
  hostnamectl set-hostname localhost
  truncate -s0 /etc/machine-id
  rm /var/lib/dbus/machine-id
  ln -s /etc/machine-id /var/lib/dbus/machine-id
  truncate -s0 ~/.bash_history
  history -c

  mkdir -p /opt/scripts
  cp -R . /opt/scripts/
  cat > /opt/scripts/vars.local <<EOF
OS_USERNAME=$OS_USERNAME
EOF
}

function install_guest_additions() {
  echo "Moving VBoxGuestAdditions.iso to /opt/tools"
  mkdir -p /opt/tools
  mv ~packer/VBoxGuestAdditions.iso /opt/tools
  echo "Mounting guest additions iso"
  mkdir /media/iso
  mount -o loop /opt/tools/VBoxGuestAdditions.iso /media/iso/

  cd /media/iso/
  set +e # exit 2 follows. Ignore it
  ./VBoxLinuxAdditions.run --nox11
  echo "Guest additions installed. Exit status: $?"
  cd - >/dev/null
  set -e
}

function init_cluster() {
  export CLUSTER_NAME="$1"

  [[ -z "$CLUSTER_NAME" ]] && echo "First argument to init_cluster should be the cluster name!" >&2 && exit 1

  echo "---- INITIALIZING CLUSTER '$CLUSTER_NAME' ----"

  init_server controller

  cat cluster-config.tpl.yaml | envsubst > "/tmp/kube-init-config.yaml"
  kubeadm init --config "/tmp/kube-init-config.yaml"

  # Without config file (needed only to set the cluster name
  # kubeadm init --config "/tmp/kube-init-config.yaml" --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.22.0 \
  #  --control-plane-endpoint "$IP:6443" --apiserver-advertise-address "$IP"

  echo "Configuring kubeconfig for root."
  export KUBECONFIG=/root/.kube/config
  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf "$KUBECONFIG"
  chown "$(id -u):$(id -g)" "$KUBECONFIG"

  echo "Installing Calico."
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

  kubectl set env daemonset/calico-node -n kube-system IP_AUTODETECTION_METHOD=interface=enp0s8

  #echo -e "\n --- Enabling the kubelet service ---\n"
  #systemctl enable kubelet
  echo "Copying kubernetes-admin kubeconfig to $OS_USERNAME."
  local user_home="$(eval echo ~"$OS_USERNAME")"
  mkdir -p "$user_home/.kube"
  cp "$KUBECONFIG" "$user_home/.kube/"
  chown -R "$OS_USERNAME" "$user_home/.kube"

  echo -e "\n The cluster should be ready (control plane might still be in 'NotReady').:\n"
  kubectl get nodes

  echo
  echo "----------------------"
  echo -e "Use the following commands to join worker nodes to the cluster if doing it manually:\n"

  echo 'cd /opt/scripts && sudo ./join-cluster.sh'
  local command="$(kubeadm token create --print-join-command)"
  echo "sudo $command"
  echo "----------------------"
}

function init_server() {
  echo "Running modprobe again shouldn't be necessary!"
  modprobe overlay
  modprobe br_netfilter

  local started_at_second=$(date +%s)
  local fail_at_second=$((started_at_second + 300)) # timeout after 5 minutes
  export IP=""
  echo "Retrieving the IP where the cluster will listen on"
  ip -4 addr show
  echo -e "Waiting ."
  while [ "$IP" == "" ]; do
    local current_second=$(date +%s)
    if [ "$current_second" -gt "$fail_at_second" ]; then
      echo "Timeout waiting for an IP-address on enp0s8. Aborting."
      exit 1
    fi
    export IP="$(ip -4 addr show enp0s8 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
  done
  export HOST_NAME="${HOST_NAME:-"$1-$RANDOM"}"

  echo "Using IP: $IP"

  echo "Setting hostname to '$HOST_NAME'"
  hostnamectl set-hostname "$HOST_NAME"
  echo "$IP $HOST_NAME" >>/etc/hosts
}

function join_cluster() {
  init_server worker
  echo "Setting nodename otherwise Calico won't be able to start. This should not be necessary!"

  mkdir -p /var/lib/calico
  echo "--- HOST_NAME for calico: = $HOST_NAME"
  echo "$HOST_NAME" >/var/lib/calico/nodename
  echo "Running the join command provided by the server (get it using: 'kubeadm token create --print-join-command')"
  local started_at_second=$(date +%s)
  local fail_at_second=$((started_at_second + 900)) # timeout after 15 minutes
  echo -e "Waiting ."
  local JOIN_COMMAND=""
  local JOIN_COMMAND_1=""
  local JOIN_COMMAND_2=""
  while [ "$JOIN_COMMAND" == "" ]; do
    local current_second=$(date +%s)
    if [ "$current_second" -gt "$fail_at_second" ]; then
      echo "Timeout waiting for the join-command guest property to be set. Aborting."
      exit 1
    fi
    get_guest_property "join-command-1"
    export JOIN_COMMAND_1="$LAST_VALUE"
    if [ -n "$JOIN_COMMAND_1" ]; then
      get_guest_property "join-command-2"
      JOIN_COMMAND_2="$LAST_VALUE"
      JOIN_COMMAND="${JOIN_COMMAND_1}${JOIN_COMMAND_2}"
      break
    fi
    sleep 5
  done
  echo "Joining with: -$JOIN_COMMAND-"
  $JOIN_COMMAND
}

function create_os_user() {
  echo "Creating OS user $OS_USERNAME."
  useradd -s /usr/bin/bash "$OS_USERNAME"
  echo "%$OS_USERNAME ALL=(ALL) NOPASSWD: ALL" >>"/etc/sudoers.d/$OS_USERNAME"
  local user_home="$(eval echo ~"$OS_USERNAME")"
  mkdir -p "$user_home/.ssh"
  chown -R "$OS_USERNAME" "$user_home"
  [ -n "$OS_USER_PUB_KEY" ] && echo "$OS_USER_PUB_KEY" >>"$user_home/.ssh/authorized_keys"
  cp vimrc.temp "$user_home/.vimrc"
}
