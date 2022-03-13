#!/usr/bin/env bash

set -euo pipefail

function set_aws_profile() {
    local force_relogin="false";
    export profile_name;
    import_args "$@";
    check_required_arguments "set_aws_profile" "profile_name";

    if [ "$profile_name" == "${AWS_PROFILE-}" ] && [ "$force_relogin" != "true" ]; then
        log_info "Not setting aws credentials to $profile_name because it's already configured and argument 'force_relogin' is not 'true'.";
        return;
    fi;

    log_info "Setting AWS_PROFILE to '$profile_name' and clearing other AWS-variables.";
    export AWS_PROFILE="$profile_name";
    unset AWS_SESSION_ID;
    unset AWS_DEFAULT_REGION;
    unset AWS_SECRET_ACCESS_KEY;
    unset AWS_ACCESS_KEY_ID;

    rm -f ~/.aws/cli/cache/* # this is used when assuming a role
    local identity="";
    local counter=0;
    while [ -z "$identity" ]; do
        counter=$((counter+1))
        local identity=$(aws sts get-caller-identity); # script exits if "local" is not used
        [[ $counter -gt 4 ]] && log_fatal "Failed 5 times to authenticate. Aborting.";
    done;

    local username=$(echo -- "$identity" | sed -n 's!.*"arn:aws:iam::.*:user/\(.*\)".*!\1!p')
    local tokens="";
    if [ -n "$username" ]; then # logging in without assuming a role
        mfa=$(aws iam list-mfa-devices --user-name "$username")
        device=$(echo -- "$mfa" | sed -n 's!.*"SerialNumber": "\(.*\)".*!\1!p')
        if [ -n "$device" ]; then
            read -rp "Enter MFA code for $device: " mfa_code;
            tokens=$(aws sts get-session-token --serial-number "$device" --token-code "$mfa_code")
        fi;
    else
        if [ -d ~/.aws/cli/cache ]; then
            local FILE=$(find ~/.aws/cli/cache/ -name "*.json")
            if [ -n "$FILE" ]; then
                tokens=$(cat "$FILE");
            fi;
        fi;
    fi;
    if [ -n "$tokens" ]; then
        export AWS_SECRET_ACCESS_KEY="$(echo "$tokens" | jq -r '.Credentials.SecretAccessKey')";
        export AWS_SESSION_TOKEN="$(echo "$tokens" | jq -r '.Credentials.SessionToken')";
        export AWS_ACCESS_KEY_ID="$(echo "$tokens" | jq -r '.Credentials.AccessKeyId')";
        expiration="$(echo "$tokens" | jq -r '.Credentials.Expiration')";
        echo "Code is valid until $expiration";
    fi;
}

function conn_aws() {
  local instance_name=""
  unset AWS_INSTANCES
  local VAR_FILE="$SHARED_REPO_DIR/data.local/cloud/aws-instances.yaml"
  if [ ! -f "$VAR_FILE" ]; then
    log_error "File not found: $VAR_FILE"
    return 1
  fi;
  import_args "$@"

  get_var "AWS_INSTANCES" "$VAR_FILE" ".instances" ""
  local instances=""
  for instance in $(echo "$AWS_INSTANCES" | yq -o json | jq -cr '.[]'); do
      local name="$(echo "$instance" | jq -r '.name')"
      local id="$(echo "$instance" | jq -r '.id')"

      if [ "$instance_name" == "$name" ]; then
        aws ssm start-session --target "$id"
        return
      fi;
      [[ -n "$instances" ]] && instances="$instances"$'\n'
      instances="$instances$id:$name"
  done
  echo "instances: $instances"
  IFS=$'\n' && select instance in $instances; do
      break
  done
  [[ -z "$instance" ]] && return

  IFS=: read -r id name <<< "$instance"

  log_info "Connecting to instance $id"
  aws ssm start-session --target "$id"

  unset AWS_INSTANCES
}
