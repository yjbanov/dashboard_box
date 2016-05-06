#!/bin/bash
set -e
set -x

function absolute_path {
  [[ $1 = /* ]] && echo "$1" || echo "$(pwd)/${1#./}"
}

DART_SDK=${DART_SDK:-"/usr/local/opt/dart/libexec"}
ROOT_DIRECTORY=$(dirname "$(dirname $(absolute_path "$0"))")

cd ${ROOT_DIRECTORY}/dashboard_box
$DART_SDK/bin/pub get
$DART_SDK/bin/dart bin/build.dart $ROOT_DIRECTORY
