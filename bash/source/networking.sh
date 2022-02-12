#!/usr/bin/env bash

set -euo pipefail

function get_default_ip() {
  log_info "Retrieving the IP address used for the default route."
  local def_route="$(route -n | grep '^0.0.0.0')"
  local iface="$(echo "${def_route##* }")"
  export LAST_VALUE="$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
}
