#!/usr/bin/env bash

set -euo pipefail

org_dir="$(pwd)"
this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

REPO_DIR="$(git rev-parse --show-toplevel)"
cd "$org_dir" >/dev/null
. "$REPO_DIR/bash/init.sh"

# ensure_nfs4_share will:
#   create the directory "$1"
#   use it as the NFS root directory (TODO: figure out why no subfolders can be mounted in the VMs when shared)
#   create a mount named "$2" and share it with IP CIDR "$3"
#   configures auto-mounting after boot
function ensure_nfs4_share() {
  local root_share_dir="$1"
  local mount_subdir="$2"
  local share_cidr="$3"
  local owner_group="$4"
  local full_share_dir="$root_share_dir/$mount_subdir"

  [[ -z "$root_share_dir" ]] && log_fatal "First argument for ensure_nfs4_share should be a directory to share."
  [[ -z "$mount_subdir" ]] && log_fatal "Second argument for ensure_nfs4_share should be a sub-directory to share under $root_share_dir."
  [[ -z "$share_cidr" ]] && log_fatal "Third argument for ensure_nfs4_share should be the CIDR to share the directory with."
  [[ -z "$owner_group" ]] && log_fatal "Fourth argument for ensure_nfs4_share should be the group id that gets owner-rights on the directory."

  if [ -d "$root_share_dir" ]; then
    log_warn "Directory '$root_share_dir' already exists. Not touching it, so make sure group '$owner_group' has enough permissions."
  else
    log_info "Creating directory '$root_share_dir' to share."
    sudo mkdir -p "$root_share_dir"
  fi

  if [ -d "$full_share_dir" ]; then
    log_warn "Directory '$full_share_dir' already exists. Not touching it, so make sure group '$owner_group' has enough permissions."
  else
    sudo chown "$(whoami)":"$owner_group" "$full_share_dir"
    log_info "Making sure directories and files created under $full_share_dir are owned by group '$owner_group'."
    sudo chmod g+s "$full_share_dir"
  fi

  log_info "Checking if '$root_share_dir' is already shared."
  if grep -q "^$root_share_dir " "/etc/exports"; then
    log_warn "Share root '$root_share_dir' already configured in /etc/exports. Not overwriting it: $(grep "^$root_share_dir " "/etc/exports" | grep -v "^#")."
  elif grep -q "fsid=0" "/etc/exports" | grep -v "^#"; then
    log_warn "A root share already exists in /etc/exports. Not able to correctly share now: $(grep "fsid=0" "/etc/exports")."
  else
    log_info "Sharing '$root_share_dir' with CIDR '$share_cidr'."
    echo "$root_share_dir         $share_cidr(fsid=0,crossmnt,rw,root_squash,sync,no_subtree_check,insecure)" | sudo tee -a /etc/exports
  fi

  log_info "Checking if '$full_share_dir' is already shared."
  if grep -q "^$full_share_dir " "/etc/exports"; then
    log_warn "Share directory '$full_share_dir' already configured in /etc/exports. Not overwriting it: $(grep "^$full_share_dir " "/etc/exports" | grep -v "^#")."
  else
    log_info "Sharing '$full_share_dir' with CIDR '$share_cidr'."
    echo "$full_share_dir         $share_cidr(rw,all_squash,anonuid=1001,anongid=80,insecure,no_subtree_check)" | sudo tee -a /etc/exports
  fi

  log_info "Activating share."
  sudo exportfs -arv
}
