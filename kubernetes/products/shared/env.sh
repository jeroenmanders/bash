#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. "$this_dir/../../env.sh"

if [ "${CLUSTER_MODE-}" == "VIRTUALBOX" ]; then
. "$REPO_DIR"/kubernetes/virtualbox/utils/env.sh
fi

get_var "REGISTRY_NAMESPACE" "$REGISTRY_CONFIG_FILE" ".registry .namespace" ""
get_var "REGISTRY_NAME" "$REGISTRY_CONFIG_FILE" ".registry .service-name" ""
get_var "REGISTRY_NODE_PORT" "$REGISTRY_CONFIG_FILE" ".registry .service-node-port" ""
export REGISTRY_HOSTNAME="${REGISTRY_NAME}.${REGISTRY_NAMESPACE}.svc.cluster.local"

function generate_certificate() {
  [[ -z "$SERVICE_NAME" ]] && log_fatal "Environment variable 'SERVICE_NAME' is expected to be set in generate_certificate."
  [[ -z "$SERVICE_NAMESPACE" ]] && log_fatal "Environment variable 'SERVICE_NAMESPACE' is expected to be set in generate_certificate."

  if [ -z "${ALT_NAMES-}" ]; then
    ALT_NAMES="$(cat << EOF
DNS.1 = ${SERVICE_NAME}
DNS.2 = ${SERVICE_NAME}.${SERVICE_NAMESPACE}
DNS.3 = ${SERVICE_NAME}.${SERVICE_NAMESPACE}.svc
DNS.4 = ${SERVICE_NAME}.${SERVICE_NAMESPACE}.svc.cluster.local
DNS.5 = '*.'"${SERVICE_NAME}"'-internal'
IP.1 = 127.0.0.1
EOF
)"
  fi
  export ALT_NAMES
  local PRIVATE_KEY_FILE="certificates-local/$SERVICE_NAME.key"
  local CSR_FILE="certificates-local/$SERVICE_NAME-server.csr"
  local SSL_CONFIG_FILE="certificates-local/$SERVICE_NAME-ssl.conf"
  export CSR_NAME="$SERVICE_NAME-csr"

  if [ -d "certificates-local" ]; then
    log_warn "Directory 'certificates-local' already exists. Moving it to /tmp."
    rm -Rf /tmp/certificates-local
    mv certificates-local/ /tmp/
  fi;

  log_info "Generating certificate for service $SERVICE_NAME in namespace $SERVICE_NAMESPACE."
  mkdir -p certificates-local

  log_info "Generating private key file."
  openssl genrsa -out $PRIVATE_KEY_FILE 4096

  log_info "Generating SSL configuration file."
  < ../shared/ssl.tpl.cnf envsubst > "$SSL_CONFIG_FILE"

  log_info "Generating signing request."
  openssl req -config "$SSL_CONFIG_FILE" -new -key "$PRIVATE_KEY_FILE" \
        -subj "/CN=system:node:$SERVICE_NAME.$SERVICE_NAMESPACE.svc;/O=system:nodes" \
        -out "$CSR_FILE"

  export BASE64_CSR="$(< "$CSR_FILE" base64 -w0)"

  log_info "Generating signing request YAML file."
  < ../shared/csr.tpl.yaml envsubst > certificates-local/$SERVICE_NAME-csr.yaml

  log_info "Creating Kubernetes CSR."
  kubectl create -f certificates-local/$SERVICE_NAME-csr.yaml

  log_info "Approving CSR."
  kubectl certificate approve "$CSR_NAME"

  log_info "Retrieving certificate data from Kubernetes."
  local CERTIFICATE_DATA=$(kubectl get csr "$CSR_NAME" -o jsonpath='{.status.certificate}')

  log_info "Generating certificate file."
  echo "$CERTIFICATE_DATA" | openssl base64 -d -A -out certificates-local/$SERVICE_NAME.crt

  log_info "Installing certificate on host"
  kubectl config view --raw --minify --flatten \
    -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d > certificates-local/$SERVICE_NAME.ca

  sudo cp certificates-local/$SERVICE_NAME.crt /usr/local/share/ca-certificates/
  sudo update-ca-certificates
}

function inspect_certificate() {
  local KEY_FILE="$1"
  local CSR_FILE="$2"
  local CRT_FILE="$3"

  log_info "Check certificate signing request:"
  openssl req -text -noout -verify -in "$CSR_FILE"
  log_info "Private key check:"
  openssl rsa -check -noout -in "$KEY_FILE"

  log_info "Private key details:"
  openssl rsa -text -noout -in "$KEY_FILE"

  log_info "Certificate details:"
  openssl x509 -text -noout -in "$CRT_FILE"

  log_info "md5 of below three modulus should be the same:"
  local key_mod="$(openssl rsa -noout -modulus -in "$KEY_FILE" | openssl md5)"
  local crt_mod="$(openssl x509 -noout -modulus -in "$CRT_FILE" | openssl md5)"
  local csr_mod="$(openssl req -noout -modulus -in "$CSR_FILE" | openssl md5)"
  echo "key: $key_mod"
  echo "crt: $crt_mod"
  echo "csr: $csr_mod"

  if [ "$key_mod" != "$crt_mod" -o "$key_mod" != "$crt_mod" ]; then
    log_error "!!! Modulus are not the same. The certificate is NOT valid!"
  else
    log_info "The certificate is valid."
  fi;
}
