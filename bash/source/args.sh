#!/usr/bin/env bash

set -euo pipefail

function import_args() {
  local varvalue=""
  local varname=""
  while [[ $# -gt 1 ]]; do
    varname="$1"
    varname=${varname//[-]/_}
    varname=$(echo "$varname" | tr "[:upper:]" "[:lower:]")
    shift
    if [[ $# -eq 0 ]]; then # variable has no value --> disabled because an argument might be: --arguments "--arg1 blabla"
      varvalue=""
    else
      varvalue="$1"
      if [[ "$varvalue" == --* ]]; then
        # next argument, this one has an empty value
        continue
      fi
      shift

      while true; do # handle spaces in variable values. Necessary for remote execution with arguments
        [[ $# -gt 0 ]] || break
        local nextvar="$1"
        if [[ -z "$nextvar" ]] || [[ "$nextvar" == --* ]]; then
          break
        fi
        varvalue="$varvalue $nextvar"
        shift
      done

    fi
    varname=${varname:2} # remove the starting --
    export "$varname"="$varvalue"
  done
}

# usage: one argument required: check_required_argument "my_function" "argument1"
#        one of two arguments required: check_required_argument "my_function" "argument1" "argument2"
function check_required_argument() {
  local calling_function_name="$1"
  local argument_name="$2"
  local argument_name2=""
  [[ $# -gt 2 ]] && argument_name2="$3"
  if [ -z "${!argument_name}" ]; then
    if [ -n "$argument_name2" ]; then
      if [ -z "${!argument_name2}" ]; then
        log_error "Argument '$argument_name' or '$argument_name2' is required for '$calling_function_name'."
        exit 1
      fi
    else
      log_error "Argument '$argument_name' is required for function '$calling_function_name'."
      exit 1
    fi
  fi
}

function check_required_arguments() {
  local calling_function_name="$1"
  while true; do
    shift
    [[ $# -gt 0 ]] || break
    local argument_name="$1"
    if [ -z "$argument_name" ]; then
      break
    fi
    check_required_argument "$calling_function_name" "$argument_name"
  done
}

function check_required_variable() {
  local function_name="$1"
  local variable_name="$2"

  if [ -z "${!variable_name-}" ]; then
      log_fatal "Required variable '$variable_name' is not set for '$function_name'."
  fi
}

function check_required_variables() {
  local function_name="$1"
  shift
  while true; do
    [[ $# -eq 0 ]] && break
    local variable_name="$1"
    if [ -z "$variable_name" ]; then
      continue
    fi
    check_required_variable "$function_name" "$variable_name"
    shift
  done
}
