# #!/usr/bin/env bash

function begin_tests() {
  export TEST_ERRORS=0;
  export tests_started_on=$(date +%s);
}

function begin_test() {
  export current_test="$1";
  export test_started_on=$(date +%s);
  echo "Testing $current_test";
}

function end_test() {  
  local test_ended_on=$(date +%s);
  local duration=$(( test_ended_on - test_started_on ));
  echo -e "\tTest took $duration seconds.";
}

function end_tests() {  
  local tests_ended_on=$(date +%s);
  local duration=$(( tests_ended_on - tests_started_on ));
  echo -e "\nTests took $duration seconds.";

  if [ "$TEST_ERRORS" != "0" ]; then
    echo -e "\n=== $TEST_ERRORS assertions failed.";
    exit 1;
  fi;
}

assert() {
  if ! eval $* ; then
      echo -e "\n===== Assertion failed:  \"$*\" =====";
      echo -e "\tLocation: line:$(caller 0)";
      TEST_ERRORS=$(( TEST_ERRORS + 1 ));
  fi  
}
