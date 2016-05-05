#!/bin/bash
set -e
set -x

function absolute_path {
  [[ $1 = /* ]] && echo "$1" || echo "$(pwd)/${1#./}"
}

ROOT_DIRECTORY=$(dirname "$(dirname $(absolute_path "$0"))")

cd ${ROOT_DIRECTORY}/dashboard_box
pub get
dart bin/build.dart $ROOT_DIRECTORY
