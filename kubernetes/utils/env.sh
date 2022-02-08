#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir"

. ./env-shared.sh

REPO_DIR="$(git rev-parse --show-toplevel)"
. "$REPO_DIR"/bash/init.sh

# Currently just one cluster can be configured.
#  Use something like the following to support multiple clusters:
#  '.kubernetes .clusters [] | select(.name-prefix == "kube") .main-user'
get_var "VM_NAME_PREFIX" "../settings.local.yml" ".kubernetes .clusters[0] .name-prefix" ""
get_var "OS_USERNAME" "../settings.local.yml" ".kubernetes  .clusters[0] .main-user" ""
get_var "AUTOSTART_VMS" "../settings.local.yml" ".virtualbox .autostart-vms" "true"
OVA_FILE="$REPO_DIR/local-resources/virtualbox/kubernetes-base/kubernetes-base.ovf"

CONTROLLER="$VM_NAME_PREFIX-controller"
WORKER="$VM_NAME_PREFIX-worker"

function configure_vbox_network() {
  if vboxmanage list hostonlyifs | grep -e '^VBoxNetworkName:.*HostInterfaceNetworking-vboxnet0' >/dev/null; then
    log_info "Host only network 'HostInterfaceNetworking-vboxnet0' is already configured. Not modifying it."
    return
  fi
  local prefix=".virtualbox .dhcp .vboxnet0"
  get_var "_TMP_IP" "../settings.local.yml" "$prefix .ip" "192.168.56.1"
  get_var "_TMP_NETMASK" "../settings.local.yml" "$prefix .netmask" "192.168.56.1"
  get_var "_TMP_LOWERIP" "../settings.local.yml" "$prefix .ip" "192.168.56.1"
  get_var "_TMP_UPPERIP" "../settings.local.yml" "$prefix .ip" "192.168.56.1"

  log_info "Configuring Virtualbox host only network vboxnet0."
  vboxmanage hostonlyif create
  vboxmanage hostonlyif ipconfig vboxnet0 --ip "$_TMP_IP"
  vboxmanage dhcpserver add --ifname vboxnet0 --ip "$_TMP_IP" --netmask "$_TMP_NETMASK" --lowerip "$_TMP_LOWERIP" --upperip "$_TMP_UPPERIP"
  vboxmanage dhcpserver modify --ifname vboxnet0 --enable
}

function install_extensions() {
  curl -o vbox-extpack https://download.virtualbox.org/virtualbox/6.1.32/Oracle_VM_VirtualBox_Extension_Pack-6.1.32.vbox-extpack
  echo "y" | vboxmanage extpack install ./vbox-extpack
}

function setup_cluster() {
  # We're using 2 join-commands because the maximum (reading) length of guest properties is 150 characters
  #   And alternative would be to generate a file and copy it to the machine (SMB or something like the following)
  # VBoxManage guestcontrol "kube-controller-1" run /bin/sh --username $OS_USERNAME --verbose --wait-stdout \
  #     --wait-stderr -- -c "echo '$JOIN_COMMAND' > /tmp/join-command.txt"
  local join_command_1=""
  local join_command_2=""

  create_vm "$CONTROLLER-1" controller
  create_vm "$WORKER-1" worker "join-command"
  create_vm "$WORKER-2" worker "join-command"

  local started_at_second=$(date +%s)
  local fail_at_second=$((started_at_second + 900)) # timeout after 15 minutes
  echo -e "Waiting for controller setup ."
  while [ "$join_command_2" == "" ]; do
    local join_command_with_value="$(vboxmanage guestproperty get "$CONTROLLER-1" join-command-2)"
    local current_second=$(date +%s)
    if [ "$current_second" -gt "$fail_at_second" ]; then
      log_info "Timeout waiting for the cluster to get initialized. Aborting."
      exit 1
    fi
    if [ -n "$join_command_with_value" ]; then
      join_command_2="${join_command_with_value#"Value: "}"
      join_command_with_value="$(vboxmanage guestproperty get "$CONTROLLER-1" join-command-1)"
      join_command_1="${join_command_with_value#"Value: "}"
    fi
    sleep 5
  done

  log_info "Setting join-command-1 for worker machines to '$join_command_1'"
  log_info "Setting join-command-2 for worker machines to '$join_command_2'"

  vboxmanage guestproperty set "$WORKER-1" join-command-1 "$join_command_1"
  vboxmanage guestproperty set "$WORKER-1" join-command-2 "$join_command_2"
  vboxmanage guestproperty set "$WORKER-2" join-command-1 "$join_command_1"
  vboxmanage guestproperty set "$WORKER-2" join-command-2 "$join_command_2"

  add_cluster_user "system:masters" "$OS_USERNAME"
}

function create_vm() {
  local vm_name="$1"
  local host_type="$2"

  log_info "Importing $OVA_FILE for $vm_name."
  vboxmanage import "$OVA_FILE" --vsys 0 --vmname "$vm_name"

  log_info "Adding second adapter.".
  vboxmanage modifyvm "$vm_name" --nic2 hostonly --hostonlyadapter2 vboxnet0

  if [ "$AUTOSTART_VMS" == "true" ]; then
    log_info "Enabling autostart"
    vboxmanage modifyvm "$vm_name" --autostart-enabled on
  else
    log_info "Not enabled autostart because AUTOSTART_VMS is '$AUTOSTART_VMS'."
  fi

  log_info "Setting guest host-name and type."
  vboxmanage guestproperty set "$vm_name" host-name "$vm_name"
  vboxmanage guestproperty set "$vm_name" host-type "$host_type"

  log_info "Starting VM $vm_name."
  vboxmanage startvm "$vm_name" --type=headless
}

function remove_cluster() {
  read -rp "Are you sure you want to remove the virtual machines? [y/N]: " answer
  [[ "$answer" != "y" ]] && log_info "Answer was not 'y' so quitting." && exit 1
  remove_vm "$CONTROLLER-1"
  remove_vm "$WORKER-1"
  remove_vm "$WORKER-2"
}

function remove_vm() {
  local vm_name="$1"
  vboxmanage controlvm "$vm_name" poweroff
  vboxmanage unregistervm --delete "$vm_name"
}

# This function runs on the controller node
function _generate_user_certs() {
  set -euo pipefail;
  [[ -z "$username" ]] && echo "Variable 'username' not set in _generate_user_certs!" && exit 1
  [[ -z "$group" ]] && echo "Variable 'group' not set in _generate_user_certs!" && exit 1
  export username group # necessary for envsubst
  local temp_dir="$(mktemp -d -p /tmp)"
  cd "$temp_dir"

  echo "Creating certificate for user '$username' with group '$group'."

  echo "Creating private key."
  openssl genrsa -out "$username.key" 4096

  echo "Creating certificate signing request."
  cat > csr.cnf << EOF
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
[ dn ]
CN = $username
O = ${username}-group
[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
EOF

  openssl req -config ./csr.cnf -new -key "$username.key" -nodes -out "$username.csr"

  echo "Converting the csr to base64."
  export BASE64_CSR=$(< ./"$username.csr" base64 -w0)

  echo "Uploading CSR"
  cat <<EOF | envsubst | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${username}-csr
spec:
  signerName: kubernetes.io/kube-apiserver-client
  groups:
  - $group
  #- system:authenticated
  # expirationSeconds: 14400
  request: ${BASE64_CSR}
  usages:
  - digital signature
  - key encipherment
  #- server auth    not available with this signerName
  - client auth
EOF

  echo "Approving CSR."
  kubectl certificate approve "${username}-csr"

  echo "Creating certificate."
  kubectl get csr "${username}-csr" -o jsonpath='{.status.certificate}' | base64 --decode >"$username.crt"

  openssl x509 -in ./"$username.crt" -noout -text

  export CLUSTER_NAME="$(kubectl config view --raw -o json | jq -r '.clusters[0] .name')"
  export CLIENT_CERTIFICATE_DATA=$(kubectl get csr "${username}-csr" -o jsonpath='{.status.certificate}')
  export CLUSTER_CA="$(kubectl config view --raw -o json | jq -r '.clusters[0] .cluster ."certificate-authority-data"')"
  export CLUSTER_ENDPOINT="$(kubectl config view --raw -o json | jq -r '.clusters[0] .cluster .server')"

  echo "CLUSTER_NAME: $CLUSTER_NAME"
  echo "CLIENT_CERTIFICATE_DATA: $CLIENT_CERTIFICATE_DATA"
  echo "CLUSTER_CA: $CLUSTER_CA"
  echo "CLUSTER_ENDPOINT: $CLUSTER_ENDPOINT"

  echo "Generating kubeconfig"
  cat << EOF | envsubst > "$(pwd)/kubeconfig"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_ENDPOINT}
  name: ${CLUSTER_NAME}
users:
- name: ${username}
  user:
    client-certificate-data: ${CLIENT_CERTIFICATE_DATA}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${username}
  name: ${username}-${CLUSTER_NAME}
current-context: ${username}-${CLUSTER_NAME}
EOF

  echo "Adding private key to kubeconfig"
  kubectl config --kubeconfig="$(pwd)/kubeconfig" set-credentials "$username" --client-key="$username.key" --embed-certs=true
  mv "$(pwd)/kubeconfig" ~/"kubeconfig-$username"
  rm -Rf "$temp_dir"

  echo "cluster-admin"
  cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${username}-cluster-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: $username

EOF
}

function add_cluster_user() {
  local group="$1"
  local username="$2"
  local user_home="$(eval echo ~)"

  [[ -z "$group" ]] && log_fatal "Please provide the group as the first argument to function 'add_cluster_user'."
  [[ -z "$username" ]] && log_fatal "Please provide the username as the second argument to function 'add_cluster_user'."

  get_vm_ip kube-controller-1 # variable "IP"" now contains the IP of the controller VM

  # shellcheck disable=SC2087
  # shellcheck disable=SC2034
  ssh "$OS_USERNAME"@"$IP" <<EOF
    $(typeset -f _generate_user_certs)
    username="$username" group="$group" _generate_user_certs
EOF

  log_info "Retrieving kubeconfig for $username copying it to $HOME/.kube/kubeconfig-$username"
  scp "$OS_USERNAME@$IP:kubeconfig-$username" ~/.kube/"kubeconfig-$username"

  log_info "Removing the kubeconfig file from the controller."
  # shellcheck disable=SC2029
  ssh "$OS_USERNAME@$IP" rm "kubeconfig-$username"

  [[ -f ~/.kube/config ]] && cp ~/.kube/config ~/.kube/config.org.$$

  import_kubeconfig ~/.kube/"kubeconfig-$username" "$user_home/.kube/config"
}

function import_kubeconfig() {
  local source_config="$1"
  local target_config="$2"

  [[ -z "$source_config" ]] && echo "First argument to import_kubeconfig should be the source kubeconfig file path." && return 1
  [[ -z "$target_config" ]] && echo "Second argument to import_kubeconfig should be the target kubeconfig file path." && return 1

  [[ ! -s "$source_config" ]] && echo "File '$source_config' not found or empty." && return 1
  [[ ! -s "$target_config" ]] && echo "File '$target_config' not found or empty." && return 1

  echo "Importing $source_config into $target_config."

  local cluster_name="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.clusters[0] .name')"
  local cluster_authority="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.clusters[0] .cluster ."certificate-authority-data"')"
  local cluster_address="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.clusters[0] .cluster .server')"
  local username="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.users[0] .name')"
  local user_cert="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.users[0] .user ."client-certificate-data"')"
  local user_key="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.users[0] .user ."client-key-data"')"
  local target_context_name="${username}-${cluster_name}"

  echo "Checking if cluster name '$cluster_name' already exists in '$target_config'."
  if kubectl config get-clusters --kubeconfig "$target_config" | grep "^$cluster_name$" > /dev/null; then
    # TODO: check if the cluster-details in both files are the same
    echo -e "\n!!!! Cluster '$cluster_name' already configured. Use it ONLY if it's the SAME one as that in '$source_config' !!!!\n"
    read -rp "Do you want to abort or use it? [A/u]: " answer
    [[ "$answer" != "u" ]] && echo "Aborting." && exit 1;
  fi

  echo "Checking if user '$username' already exists in '$target_config'."
  if kubectl config get-users --kubeconfig "$target_config" | grep "^$username$" > /dev/null; then
    echo -e "\n!!!! User '$username' already configured. Aborting !!!!\n"
    return 1
  fi

  echo "Checking if context '$target_context_name' already exists in '$target_config'."
  if kubectl config get-contexts --kubeconfig "$target_config" -o name | grep "^$target_context_name$" > /dev/null; then
    echo -e "\n!!!! Context '$target_context_name' already exists. Aborting !!!!\n"
    return 1
  fi

  echo "Starting to merge. Creating backup of target config as '/tmp/config-copy-$$"
  cp "$target_config" "/tmp/config-copy-$$"

  echo "$cluster_authority" > /tmp/$$
  kubectl config set-cluster "$cluster_name" --server="$cluster_address" \
        --certificate-authority="/tmp/$$" --embed-certs=true --kubeconfig="$target_config"

  echo "$user_cert" > /tmp/$$
  kubectl config set-credentials "$username" --client-certificate="/tmp/$$" --embed-certs=true --kubeconfig="$target_config"

  echo "$user_key" > /tmp/$$
  kubectl config set-credentials "$username" --client-key="/tmp/$$" --embed-certs=true --kubeconfig="$target_config"

  kubectl config set-context "$target_context_name" --cluster="$cluster_name" --user "$username" --kubeconfig="$target_config"

  rm /tmp/$$

  echo "Config import complete"
  echo -e "\tUse 'kubectl config get-contexts --kubeconfig $target_config' to list available contexts."
  echo -e "\tActivate a context with 'kubectl config use-context my-context-name  --kubeconfig $target_config'."
}
