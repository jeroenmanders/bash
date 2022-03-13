#!/usr/bin/env bash

if [ -n "$1" ]; then
  SUFFIX="$1";
else
  read -rp "Enter suffix (dev, stg, prod): " SUFFIX;
fi;

./add-cluster-user.sh

create_kubernetes_user "jeroen"

NAMESPACE="infraxys-$SUFFIX";

if kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  echo "Namespace exists";
else
  kubectl create ns "$NAMESPACE";
fi;

kubectl apply -f yaml -n "$NAMESPACE";

