#!/usr/bin/env bash

set -euo pipefail;

export LOG_LEVEL="INFO";

SOURCE_SOURCED="${SOURCE_SOURCED-false}";

if [ "$SOURCE_SOURCED" == "true" ]; then
  log_debug "files under source/* already sourced."; # only source scripts once
else
  this_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

  for f in $this_dir/source/*.sh; do
    source "$f"; 
  done;
  SOURCE_SOURCED="true";
fi;
