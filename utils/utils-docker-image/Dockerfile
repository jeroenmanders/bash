FROM ubuntu:22.04

RUN DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get upgrade -y

RUN apt-get -y install git jq curl wget && \
    wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod a+x /usr/local/bin/yq

RUN mkdir /shared

RUN git clone https://github.com/jeroenmanders/shared.git /shared
#
RUN /shared/utils/install-aws-cli.sh
#RUN    /shared/utils/install/install-go.sh && \
#    /shared/utils/install/install-helm.sh && \
#    /shared/utils/install/install-kubectl.sh && \
#    /shared/utils/install/install-packer.sh && \
#    /shared/utils/install/install-terraform.sh && \
#    /shared/utils/install/install-vault.sh


# yq


