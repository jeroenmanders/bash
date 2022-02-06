# Kubernetes on VirtualBox

This module contains everything necessary to set up a Kubernetes cluster under VirtualBox.  
It will create one controller and two workers.

This has been tested on Ubuntu 20.04 LTS.

## Prerequisites

- `git`, `jq` and `yq` are installed. (run `utils/install-utils.sh` to install these)

## Steps

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

### Create a base VirtualBox OVF

> Any existing files under <REPO_DIR>/local-resources/virtualbox/kubernetes-base will be removed!

- Open directory "kubernetes/virtualbox/kubernetes-base-image".
- Make sure you have an SSH-key file. You can create one using `ssh-keygen -t ed25519 -C jeroen@manders.be`.
- Copy `variables.auto.pkrvars.hcl.example` to `variables.auto.pkrvars.hcl` and update its contents.
- Run `./create-image.sh`

The necessary files will be downloaded if they aren't available yet.  

### Creating the Kubernetes cluster

This involves the following steps:
- Copy `settings.local.example.yml` to `kubernetes/settings.local.yml` and adjust its values.
- Execute `./setup-cluster.sh` in the utils-directory.
