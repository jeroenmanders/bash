#!/usr/bin/env bash

set -euo pipefail

this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$this_dir" || exit 1

. ../../env.sh

function build_image() {
  log_info "Creating Kubernetes resources."
#  local DOCKER_CONFIG="$(< ../../templates/local-docker-config.json envsubst)"
#
#  cat templates/020-docker-file-cm.yaml | \
#      yq '.data ."config.json" = "'"$DOCKER_CONFIG"'"' \
#      > yaml/020-docker-file-cm-local.yaml

#  cat yaml/*.yaml | envsubst | kubectl apply -n "$KANIKO_NAMESPACE" -f -
#  return


#  tar -cf - Dockerfile | gzip -9 | kubectl run kaniko -n "$KANIKO_NAMESPACE" \
#    --rm --stdin=true --image=gcr.io/kaniko-project/executor:latest --restart=Never \
#    --overrides="$(cat overrides.json)"


    echo -e 'FROM alpine \nRUN echo "created from standard input"' > Dockerfile | tar -cf - Dockerfile | gzip -9 | kubectl run kaniko \
      -n "$KANIKO_NAMESPACE" --rm --stdin=true \
      --image=gcr.io/kaniko-project/executor:latest --restart=Never \    --overrides="$(cat overrides.json)"

#image: harbor.gait.dhl.com/cicd/kaniko-executor:debug
#command: ["/busybox/sh", "-c"]
#args:
#  [
#    "IMAGE=`cat $(results.image.path)`;
#    executor --use-new-run --dockerfile=$(params.dockerfile) --context=$(workspaces.source.path)/$(params.context) --destination=${IMAGE} --digest-file=/tekton/results/IMAGE-DIGEST --cleanup >> /workspace/source/log.txt 2>&1"
#  ]
#securityContext:
#  runAsUser: 0

}

build_image
