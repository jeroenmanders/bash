#!/usr/bin/env bash

set -euo pipefail

export ON_OSX="false"
export ON_LINUX="false"
export ON_AMAZON_LINUX="false"
export ON_UBUNTU="false"

export IS_DEBIAN="false"
export IS_REDHAT="false"
export IS_FEDORA="false"

export OS_TYPE="$(uname)"

if [ "$OS_TYPE" == "Linux" ]; then
  export ON_LINUX="true"
  if [ -f "/etc/os-release" ]; then
    . /etc/os-release
    export OS_VERSION_ID="$VERSION_ID" # 2017.09, 18.04
    if [ "$ID_LIKE" == "debian" ]; then
      IS_DEBIAN="true"
    elif  [ "$ID_LIKE" == "fedora" ]; then
      IS_FEDORA="true"
    elif  [ "$ID_LIKE" == "rhel" ]; then
      IS_REDHAT="true"
    fi
    if [ "$ID" == "amzn" ]; then
      export ON_AMAZON_LINUX="true"
    elif [ "$ID" == "ubuntu" ]; then
      export ON_UBUNTU="true"
    fi
    if [ "$ID" == "amzn" ] || [ "$ID" == "ubuntu" ]; then
      export OS_MAJOR_VERSION="$(echo "$VERSION_ID" | cut -d '.' -f1)"
      export OS_MINOR_VERSION="$(echo "$VERSION_ID" | cut -d '.' -f2)"
    fi
  fi
else
  if [ "$OS_TYPE" == "Darwin" ]; then
    export ON_OSX="true"
  fi
fi
