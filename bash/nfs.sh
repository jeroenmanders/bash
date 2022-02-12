#!/usr/bin/env bash

set -euo pipefail

org_dir="$(pwd)"
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

REPO_DIR="$(git rev-parse --show-toplevel)";
cd "$org_dir" >/dev/null
. "$REPO_DIR/bash/init.sh"

# ensure_nfs4_share will:
#   create the directory "$1"
#   use it as the NFS root directory (TODO: figure out why no subfolders can be mounted in the VMs when shared)
#   create a mount named "$2" and share it with IP CIDR "$3"
#   configures auto-mounting after boot
function ensure_nfs4_share() {
  local share_dir="$1"
  local share_cidr="$2"

  [[ -z "$share_dir" ]] && log_fatal "First argument for ensure_nfs4_share should be a directory to share."
  [[ -z "$share_cidr" ]] && log_fatal "Third argument for ensure_nfs4_share should be the CIDR to share the directory with."

  if [ -d "$share_dir" ]; then
    log_warn "Directory '$share_dir' already exists. Not touching it, so make sure '$(whoami)' has write-rights."
  else
    log_info "Creating directory '$share_dir' to share."
    sudo mkdir -p "$share_dir"
    sudo chown "$(whoami)" "$share_dir"
  fi

  if grep -q "^$share_dir " "/etc/exports"; then
    log_warn "Share root '$share_dir' already configured in /etc/exports. Not overwriting it: $(grep "^$share_dir " "/etc/exports")."
  elif grep -q "fsid=0" "/etc/exports" | grep -v "^#"; then
    log_warn "A root share already exists in /etc/exports. Not able to correctly share now: $(grep "fsid=0" "/etc/exports")."
  else
    log_info "Sharing '$share_dir' with CIDR '$share_cidr'."
    echo "$share_dir         $share_cidr(fsid=0,crossmnt,rw,root_squash,sync,no_subtree_check,insecure)" | sudo tee -a /etc/exports
  fi

  log_info "Activating share."
  sudo exportfs -arv
}
