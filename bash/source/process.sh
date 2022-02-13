#!/usr/bin/env bash

set -euo pipefail

function wait_for_background_jobs() {
  local job_count=0
  for job in $(jobs -p); do
    job_count=$((job_count + 1))
  done
  log_info "Waiting for $job_count background jobs."
  export FAILED_JOBS=0
  for job in $(jobs -p); do
    if ! wait "$job"; then
      FAILED_JOBS=$((FAILED_JOBS + 1))
    fi
  done

  if [ $FAILED_JOBS -gt 0 ]; then
    log_warn "Failed background jobs: $FAILED_JOBS"
  fi
  log_info "All background jobs have finished."
}
