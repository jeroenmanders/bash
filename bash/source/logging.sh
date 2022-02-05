#!/usr/bin/env bash

#
# Bash logging functions
#
# @author jeroenmanders
#

export LOG_LEVEL="INFO";

declare -A LOG_LEVELS=( ["TRACE"]=0 ["DEBUG"]=2 ["INFO"]=4 ["WARN"]=8 ["ERROR"]=16 ["FATAL"]=32 );

function log_text() {
  local log_level="$1";
  local log_message="$2";
  local datepart=$(date +"%Y-%m-%d %H:%M:%S,%4N");

  if [ ! "${LOG_LEVELS[$log_level]}" ]; then
    log_message="[ INVALID LOG LEVEL!! ] $log_message";
  fi;

  # Check if the passed log_level is valid and show message always if it's not
  if eval '[ ${'LOG_LEVELS'['"$log_level"']+dummy} ]'; then
    local message_level=${LOG_LEVELS["$log_level"]};
  else
    local message_level=${LOG_LEVELS["FATAL"]};
    echo >&2;
    echo "------------------" >&2;
    echo -e "\tLog level '$log_level' is an invalid log level!!" >&2;
    echo -e "\tSupported values: TRACE DEBUG INFO WARN ERROR FATAL." >&2;
    echo "------------------" >&2;
    echo >&2;
  fi;
 
  # Check if the 'LOG_LEVEL'-variable is valid and show message always if it's not
  if eval '[ ${'LOG_LEVELS'['$LOG_LEVEL']+dummy} ]'; then
    local enabled_level=${LOG_LEVELS["$LOG_LEVEL"]};
  else
    local enabled_level=${LOG_LEVELS["TRACE"]};
    echo >&2;
    echo "------------------" >&2;
    echo -e "\tVariable 'LOG_LEVEL' has invalid value '$LOG_LEVEL'!!" >&2;
    echo -e "\tSupported values: TRACE DEBUG INFO WARN ERROR FATAL." >&2;
    echo "------------------" >&2;
    echo >&2;
  fi;

  if [ "$message_level" -ge "$enabled_level" ]; then
    echo  "[$datepart] [$(hostname)] [$log_level] [$(whoami)] $log_message";
  fi;
}

function log_trace() {
	log_text "TRACE" "$1";
}

function log_debug() {
	log_text "DEBUG" "$1";
}

function log_info() {
	log_text "INFO " "$1";
}

function log_warn() {
	log_text "WARN " "$1";
}

function log_error() {
	local message="$(log_text "ERROR" "$1")";
  echo "$message" >&2;
}

function log_fatal() {
  local message="$(log_text "FATAL" "$1")";
  echo "$message" >&2;
  exit 1;
}

