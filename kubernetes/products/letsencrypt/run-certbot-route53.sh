#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$this_dir/env.sh"

get_var "LETSENCRYPT_AWS_PROFILE" "$SETTINGS_DIR/letsencrypt.local.yaml" ".letsencrypt .aws-profile" "Default value"

function usage() {
  echo "Usage: ./run-certbot-route53.sh --aws_profile 'my-profile'"
}

function run_certbot_route53() {
  local letsencrypt_dir="$this_dir/letsencrypt.local"

  set_aws_profile --profile_name "$LETSENCRYPT_AWS_PROFILE"
  mkdir -p "$letsencrypt_dir"
  sudo docker run -it --rm --name certbot \
              -v "$letsencrypt_dir:/etc/letsencrypt" \
              -e "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" \
              -e "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" \
              -e "AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN" \
              certbot/dns-route53:v1.23.0 certonly
}

run_certbot_route53 "$@"
