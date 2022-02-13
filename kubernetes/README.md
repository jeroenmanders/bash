# Kubernetes on VirtualBox

This module contains everything necessary to set up a Kubernetes cluster under VirtualBox.  
It will create one controller and two workers.

This has been tested on Ubuntu 20.04 LTS.

## Prerequisites

- `git`, `jq` and `yq` are installed. (run `utils/install-utils.sh` to install these)

## Configuration

Yaml files under `settings` are used by all scripts in this tree.  
Copy `*.local.example.yaml` removing `.example` to get started.

## Installation steps

### Install VirtualBox

Don't use `apt-get install -y virtualbox-6.1` because it's missing some resources.  

Run the following script from within the repository folder:
```shell
REPO_DIR="$(git rev-parse --show-toplevel)";
"$REPO_DIR/utils/install-virtualbox.sh";
```

### Install Packer

```shell
REPO_DIR="$(git rev-parse --show-toplevel)";
"$REPO_DIR/utils/install-packer.sh";
```

### Install kubectl

```shell
REPO_DIR="$(git rev-parse --show-toplevel)";
"$REPO_DIR/utils/install-kubectl.sh";
```

### Configure NFS

A host share is created and write-access is granted to the configured group-id".
This group-id is configured in `settings/005.virtualbox.local.yaml`.

Run this on the host to add
```shell
GROUP_ID="<group id from the settings-file>"
OS_USERNAME="$(whoami)" 
# Create the group:
sudo groupadd -g "$GROUP_ID" host-share-user

# Add the current user to the group
sudo usermod -a -G "$GROUP_ID" "$OS_USERNAME"
```

### Create a base VirtualBox OVF

> Any existing files under <REPO_DIR>/local-resources/virtualbox/kubernetes-base will be removed!

- cd into directory `kubernetes/virtualbox/kubernetes-base-image`.
- Run `./create-image.sh`

The necessary files will be downloaded if they aren't available yet.  

### Creating the Kubernetes cluster

This involves the following steps:
- cd into directory `utils`
- Execute `./setup-cluster.sh` in the utils-directory.

### Adding Kubernetes administrators

