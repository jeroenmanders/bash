#!/usr/bin/env bash

set -euo pipefail;

export LOG_LEVEL="INFO";

SOURCE_SOURCED="${SOURCE_SOURCED-false}";

if [ "$SOURCE_SOURCED" == "true" ]; then
  log_debug "files under source/* already sourced."; # only source scripts once
else
  source_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/source;

  for f in $source_dir/*.sh; do 
    source "$f"; 
  done;
  SOURCE_SOURCED="true";
fi;
