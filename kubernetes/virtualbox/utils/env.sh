#!/usr/bin/env bash

set -euo pipefail

old_dir="$(pwd)"
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir"

. ../env.sh
. ./env-shared.sh
. "$REPO_DIR/bash/nfs.sh"

OVA_FILE="$REPO_DIR/local-resources/virtualbox/kubernetes-base/kubernetes-base.ovf"

cd "$old_dir" || exit 1

function get_guest_property() {
  local vm_name="$1"
  local name="$2"
  local with_value="$(vboxmanage guestproperty get "$vm_name" "$name")"

  if [[ "$with_value" != "Value: "* ]]; then
    export LAST_VALUE=""
    return
  fi

  export LAST_VALUE="${with_value#"Value: "}"
}

function configure_vbox_network() {
  if vboxmanage list hostonlyifs | grep -e '^VBoxNetworkName:.*HostInterfaceNetworking-vboxnet0' >/dev/null; then
    log_info "Host only network 'HostInterfaceNetworking-vboxnet0' is already configured. Not modifying it."
    return
  fi
  local prefix=".virtualbox .dhcp .vboxnet0"
  get_var "_TMP_IP" "$VBOX_CONFIG_FILE" "$prefix .ip" "192.168.56.1"
  get_var "_TMP_NETMASK" "$VBOX_CONFIG_FILE" "$prefix .netmask" "192.168.56.1"
  get_var "_TMP_LOWERIP" "$VBOX_CONFIG_FILE" "$prefix .ip" "192.168.56.1"
  get_var "_TMP_UPPERIP" "$VBOX_CONFIG_FILE" "$prefix .ip" "192.168.56.1"

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
  [[ -z "$CLUSTER_NAME" ]] && echo "Variable 'CLUSTER_NAME' not set!" && exit 1
  local MOUNT_POINT="kubernetes-shared/$CLUSTER_NAME"

  get_default_ip
  local default_ip="$LAST_VALUE"

  # We're using 2 join-commands because the maximum (reading) length of guest properties is 150 characters
  #   And alternative would be to generate a file and copy it to the machine (SMB or something like the following)
  # VBoxManage guestcontrol "kube-controller-1" run /bin/sh --username $OS_USERNAME --verbose --wait-stdout \
  #     --wait-stderr -- -c "echo '$JOIN_COMMAND' > /tmp/join-command.txt"
  local join_command_1=""
  local join_command_2=""

  get_var "ROOT_SHARE_DIR" "$K8S_CONFIG_FILE" ".kubernetes .nfs .share .root" ""
  get_var "SHARE_WITH_CIDR" "$K8S_CONFIG_FILE" ".kubernetes .nfs .share .share-with-cidr" ""

  if [ -z "$ROOT_SHARE_DIR" ]; then
    log_warn "No NFS-share root configured in the kubernetes configuration file."
  else
    ensure_nfs4_share "$ROOT_SHARE_DIR" "$MOUNT_POINT" "$SHARE_WITH_CIDR" "$OS_GROUP_ID"
  fi

  create_vm "$CONTROLLER-1" "controller" "false" "$default_ip" "/$MOUNT_POINT"
  create_workers

  # wait_for_background_jobs # -> commented out because VirtualBox is not happy with too many instance creations at once

  vboxmanage guestproperty set "$CONTROLLER-1" "cluster-name" "$CLUSTER_NAME"
  start_vm "$CONTROLLER-1"

  local started_at_second=$(date +%s)
  local fail_at_second=$((started_at_second + 900)) # timeout after 15 minutes
  echo -e "Waiting for controller setup ."
  while [ "$join_command_2" == "" ]; do
    get_guest_property "$CONTROLLER-1" "join-command-2"
    local join_command_with_value="$LAST_VALUE"
    local current_second=$(date +%s)
    if [ "$current_second" -gt "$fail_at_second" ]; then
      log_info "Timeout waiting for the cluster to get initialized. Aborting."
      exit 1
    fi
    if [ -n "$join_command_with_value" ]; then
      join_command_2="${join_command_with_value#"Value: "}"
      get_guest_property "$CONTROLLER-1" "join-command-1"
      local join_command_with_value="$LAST_VALUE"
      join_command_1="${join_command_with_value#"Value: "}"
    fi
    sleep 5
  done

  # shellcheck disable=SC2153
  for i in $(seq 1 "$WORKERS"); do
    #    create_vm "$WORKER-$i" "worker" "true" "$default_ip" "$/MOUNT_POINT"
    log_info "Setting join-command-1 for worker machines to '$join_command_1'"
    vboxmanage guestproperty set "$WORKER-$i" join-command-1 "$join_command_1"
    log_info "Setting join-command-2 for worker machines to '$join_command_2'"
    vboxmanage guestproperty set "$WORKER-$i" join-command-2 "$join_command_2"
    start_vm "$WORKER-$i"
  done

  create_administrators
  install_tools
  install_products
}

function create_workers() {
  for i in $(seq 1 "$WORKERS"); do
      sleep 1 # let vboxmanage settle ...
      create_vm "$WORKER-$i" "worker" "false" "$default_ip" "/$MOUNT_POINT"
  done
}

function create_vm() {
  local vm_name="$1"
  local host_type="$2"
  local auto_start="$3"
  local host_ip="$4"
  local mount_point="$5"

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

  log_info "Setting guest host-name to '$vm_name', host-type to '$host_type'."
  vboxmanage guestproperty set "$vm_name" host-name "$vm_name"
  vboxmanage guestproperty set "$vm_name" host-type "$host_type"

  log_info "Setting host-ip to '$host_ip' and mount-point to '$mount_point' so that the client can create an NFS-mount."
  vboxmanage guestproperty set "$vm_name" "host-ip" "$host_ip"
  vboxmanage guestproperty set "$vm_name" "mount-point" "$mount_point"

  if [ "$auto_start" == "true" ]; then
    start_vm "$vm_name"
  fi
}

function start_vm() {
  local vm_name="$1"

  [[ -z "$vm_name" ]] && echo "First argument to start_vm should be the VM name!" >&2 && exit 1

  log_info "Starting VM $vm_name."
  vboxmanage startvm "$vm_name" --type=headless
}

function remove_cluster() {
  set +e
  read -rp "Are you sure you want to remove the virtual machines? [y/N]: " answer
  [[ "$answer" != "y" ]] && log_info "Answer was not 'y' so quitting." && exit 1
  remove_vm "$CONTROLLER-1"
  for i in $(seq 1 "$WORKERS"); do
    remove_vm "$WORKER-$i"
  done
}

function remove_vm() {
  local vm_name="$1"
  log_info "Stopping and removing '$vm_name'."
  vboxmanage controlvm "$vm_name" poweroff
  vboxmanage unregistervm --delete "$vm_name"
}

# This function runs on the controller node
function _generate_user_certs() {
  set -euo pipefail
  [[ -z "$username" ]] && echo "Variable 'username' not set in _generate_user_certs!" && exit 1
  [[ -z "$group" ]] && echo "Variable 'group' not set in _generate_user_certs!" && exit 1
  export username group # necessary for envsubst
  local temp_dir="$(mktemp -d -p /tmp)"
  cd "$temp_dir"

  echo "Creating certificate for user '$username' with group '$group'."

  echo "Creating private key."
  openssl genrsa -out "$username.key" 4096

  echo "Creating certificate signing request."
  cat >csr.cnf <<EOF
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
  export BASE64_CSR=$(base64 <./"$username.csr" -w0)

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

  echo "----------- cert:"
  kubectl get csr "${username}-csr" -o jsonpath='{.status.certificate}'

  echo "Waiting 5 seconds because retrieving the certificate immediately sometimes results in an empty cert."
  sleep 5

  echo "----------- cert:"
  kubectl get csr "${username}-csr" -o jsonpath='{.status.certificate}'

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
  cat <<EOF | envsubst >"$(pwd)/kubeconfig"
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
  cat <<EOF | kubectl apply -f -
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

function create_administrators() {
  log_info "Retrieving administrators from $K8S_CONFIG_FILE."

  get_var "KUBERNETES_USERS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .kubernetes-admins" ""
  for user in $(echo "$KUBERNETES_USERS" | yq '.[] .name'); do
    echo "Processing user '$user'"
    add_cluster_user "system:masters" "$user"
  done
}

function add_cluster_user() {
  local group="$1"
  local username="$2"

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
  chmod 600 ~/.kube/"kubeconfig-$username"

  log_info "Removing the kubeconfig file from the controller."
  # shellcheck disable=SC2029
  ssh "$OS_USERNAME@$IP" rm "kubeconfig-$username"

  if [ "$MERGE_KUBECONFIGS" == "true" ]; then
    export LAST_ADMIN_KUBECONFIG="$USER_HOME/.kube/config"
    import_kubeconfig ~/.kube/"kubeconfig-$username" "$USER_HOME/.kube/config"
  else
    export LAST_ADMIN_KUBECONFIG="$USER_HOME/.kube/kubeconfig-$username"
    # shellcheck disable=SC2088
    echo "$LAST_ADMIN_KUBECONFIG generated."
  fi
}

function import_kubeconfig() {
  local source_config="$1"
  local target_config="$2"

  [[ -z "$source_config" ]] && echo "First argument to import_kubeconfig should be the source kubeconfig file path." && return 1
  [[ -z "$target_config" ]] && echo "Second argument to import_kubeconfig should be the target kubeconfig file path." && return 1

  [[ ! -s "$source_config" ]] && echo "File '$source_config' not found or empty." && return 1
  [[ ! -s "$target_config" ]] && echo "File '$target_config' not found or empty." && return 1

  [[ -f ~/.kube/config ]] && cp ~/.kube/config ~/.kube/config.org.$$

  echo "Importing $source_config into $target_config."

  local cluster_name="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.clusters[0] .name')"
  local cluster_authority="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.clusters[0] .cluster ."certificate-authority-data"')"
  local cluster_address="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.clusters[0] .cluster .server')"
  local username="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.users[0] .name')"
  local user_cert="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.users[0] .user ."client-certificate-data"')"
  local user_key="$(kubectl config view --raw -o json --kubeconfig="$source_config" | jq -r '.users[0] .user ."client-key-data"')"
  local target_context_name="${username}-${cluster_name}"

  echo "Checking if cluster name '$CLUSTER_NAME' already exists in '$target_config'."
  if kubectl config get-clusters --kubeconfig "$target_config" | grep "^$CLUSTER_NAME$" >/dev/null; then
    # TODO: check if the cluster-details in both files are the same
    echo -e "\n!!!! Cluster '$CLUSTER_NAME' already configured. Use it ONLY if it's the SAME one as that in '$source_config' !!!!\n"
    read -rp "Do you want to abort or use it? [A/u]: " answer
    [[ "$answer" != "u" ]] && echo "Aborting." && exit 1
  fi

  echo "Checking if user '$username' already exists in '$target_config'."
  if kubectl config get-users --kubeconfig "$target_config" | grep "^$username$" >/dev/null; then
    echo -e "\n!!!! User '$username' already configured. Aborting !!!!\n"
    return 1
  fi

  echo "Checking if context '$target_context_name' already exists in '$target_config'."
  if kubectl config get-contexts --kubeconfig "$target_config" -o name | grep "^$target_context_name$" >/dev/null; then
    echo -e "\n!!!! Context '$target_context_name' already exists. Aborting !!!!\n"
    return 1
  fi

  echo "Starting to merge. Creating backup of target config as '/tmp/config-copy-$$"
  cp "$target_config" "/tmp/config-copy-$$"

  echo "$cluster_authority" >/tmp/$$
  kubectl config set-cluster "$CLUSTER_NAME" --server="$cluster_address" \
    --certificate-authority="/tmp/$$" --embed-certs=true --kubeconfig="$target_config"

  echo "$user_cert" >/tmp/$$
  kubectl config set-credentials "$username" --client-certificate="/tmp/$$" --embed-certs=true --kubeconfig="$target_config"

  echo "$user_key" >/tmp/$$
  kubectl config set-credentials "$username" --client-key="/tmp/$$" --embed-certs=true --kubeconfig="$target_config"

  kubectl config set-context "$target_context_name" --cluster="$CLUSTER_NAME" --user "$username" --kubeconfig="$target_config"

  rm /tmp/$$

  echo "Config import complete"
  echo -e "\tUse 'kubectl config get-contexts --kubeconfig $target_config' to list available contexts."
  echo -e "\tActivate a context with 'kubectl config use-context my-context-name  --kubeconfig $target_config'."
}

function install_tools() {
  local system_namespace="kube-system"
  log_info "Using kubeconfig: $LAST_ADMIN_KUBECONFIG"
  export KUBECONFIG="$LAST_ADMIN_KUBECONFIG"

  log_info "Applying resources from ./kubernetes-resources/"
  cat ../kubernetes-resources/* | envsubst | kubectl apply -n "$system_namespace" -f -

  get_var "INSTALL_LOCAL_PROVISIONERS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .install-local-provisioner" "false"
  if [ "$INSTALL_LOCAL_PROVISIONERS" == "true" ]; then
    log_info "Installing Helm chart 'sig-storage-local-static-provisioner'."
    local chart="../charts/sig-storage-local-static-provisioner"
    helm install -f "./local-provisioner-values.yaml" --namespace "$system_namespace" \
      sig-storage-local-static-provisioner  "$chart"
  else
    log_warn "Not installing local provisioner because setting 'install-local-provisioner' is not 'true'."
  fi
}

function install_products() {
  get_var "PRODUCTS" "$K8S_CONFIG_FILE" ".kubernetes .clusters[0] .products" ""
  for product in $(echo "$PRODUCTS" | yq -o json '.[]' | jq -cr); do
    local name="$(echo "$product" | jq -r '.name')"
    local install="$(echo "$product" | jq -r '."auto-install"')"
    local file="$(echo "$product" | jq -r '."install-file"')"
    if [ "$install" != "true" ]; then
      log_info "Not auto-installing product '$name'."
      continue
    fi
    log_info "Installing product '$name' from '$file'."
    "$REPO_DIR/kubernetes/$file"
  done
}

function get_random_node_internal_ip() {
  export LAST_VALUE="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
}
