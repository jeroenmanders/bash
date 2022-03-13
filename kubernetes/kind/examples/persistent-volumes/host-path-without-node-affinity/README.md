# Persistent volume examples

From: https://mauilion.dev/posts/kind-pvc/

## Host path without node affinity

These volumes remain after removing a cluster.

Pods that re-use a volume don't need to be on the same node.

## Building Controller Docker image

Run build-and-push-controller-image.sh
