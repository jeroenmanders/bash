#!/usr/bin/env bash

set -euo pipefail;

cd ..; # avoid that every script in .. needs to figure out its location
. ./init.sh;
. ./yaml.sh;

YAML_FILE="/tmp/test-yaml.yaml";
YAML_VALUE="YAML value";

function prepare() {
  begin_tests;
  cat > "$YAML_FILE" <<EOF
parent:
  var-value: $YAML_VALUE
EOF
}

function cleanup() {
  rm "$YAML_FILE";
  end_tests;
}

function test_yaml() {
  prepare;
  set -e;
  begin_test "with existing environment variable.";
    value="Existing";
    ENV_VAR="$value";
    get_var "ENV_VAR" "$YAML_FILE" ".parent .var-value" "Default value";
    assert [[ '$ENV_VAR' == '$value' ]];
  end_test;
 
  begin_test "without environment variable, but with yaml value.";
    unset ENV_VAR;
    get_var "ENV_VAR" "$YAML_FILE" ".parent .var-value" "Default value";
    assert [[ '$ENV_VAR' == '$YAML_VALUE' ]];
  end_test;

  begin_test "default value.";
    value="Default value";
    unset ENV_VAR;
    get_var "ENV_VAR" "$YAML_FILE" ".parent .not-exist-var-value" "$value";
    assert [[ '$ENV_VAR' == '$value' ]];
  end_test;
  cleanup;
}

test_yaml;
