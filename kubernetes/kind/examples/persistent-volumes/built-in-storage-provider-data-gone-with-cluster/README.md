# Persistent volume examples

From: https://mauilion.dev/posts/kind-pvc/

## Built in storage provider 

This example creates a cluster and a pod with a PVC.

The files in the volume are removed when the cluster is deleted.

When the pod needs to be rescheduled, then it will only do that on the same host because of node-affinity where the first pod was created.

Test this using:

```shell
./run-pvc.sh
k get pods -o wide
podname="<PODNAME HERE>"
node="<POD NODE HERE>"

echo "Writing pod's hostname to /pvc/hostname"
kubectl exec -it $podname -- sh -c 'hostname > /pvc/hostname'

echo "Draining the pod's node so a new pod is scheduled"
kubectl drain --ignore-daemonsets $node

echo "The new pod cannot start because of node-affinity with $node:"
kubectl describe pods 

echo "If a add replicas to the deployment, then those won't be scheduled either"
kubectl scale deployment test --replicas=3 
sleep 5
kubectl get pods -o wide

kubectl get events | grep Failed

echo "Uncordoning the node"
kubectl uncordon "$node"

echo "Now all three pods will be running and have R/W-access to /pvc/hostsname"

```

