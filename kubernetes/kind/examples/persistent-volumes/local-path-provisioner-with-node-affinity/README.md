# Persistent volume examples

From: https://mauilion.dev/posts/kind-pvc/

## Built in storage provider 

This example creates a cluster and a pod with a PVC.

The files in the volume are removed when the cluster is deleted.

When the pod needs to be rescheduled, then it will only do that on the same host because of node-affinity where the first pod was created.

Test this using:

```shell
./setup.sh
kubctl get pods -o wide
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

## local-path-provisioner

This example creates a cluster and a pod with a PVC.

The files in the volume remain even if the cluster is deleted.

Test this using:

```shell
./run-local-path-provisioner.sh

echo  "Scheduling a pod with a pvc"
kubectl apply -f pvc-test.yaml
k get pods -o wide
podname="<PODNAME HERE>"
node="<POD NODE HERE>"

echo "The local-path-provisioner is configured via a configmap:"
kubectl describe configmaps -n local-path-storage local-path-config

echo "Writing pod's hostname to /pvc/hostname"
kubectl exec -it $podname -- sh -c 'hostname > /pvc/hostname'

echo "This is now also visible on the host in the 'hostPath'-directory from the kind-yaml file."

echo "Export the persistent volume"

kubectl get pv -o yaml | yq '.items[0]' > pv-backup.local.yaml

echo "Change 'persistentVolumeReclaimPolicy: Delete' to 'persistentVolumeReclaimPolicy: Retain'"
echo "See pv-backup.example.yaml for an example."
read -p "Remove any obsolete line from pv-backup.local.yaml. Press enter to continue."

kind delete cluster --name lp-provisioner-example

./run-local-path-provisioner.sh

echo "Create volume from backup"
kubectl apply -f pv-backup.local.yaml
echo  "Scheduling a pod with a pvc"
kubectl apply -f pvc-test.yaml

echo "The pod should now see the contents of the initial volume"
```
