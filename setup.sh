#!/bin/bash

################################################################################
# WARNING: DO NOT EDIT THIS FILE. EDIT run.sh INSTEAD.
#
# This file auto updates the dashboard builder code prior to running it, then
# runs `run.sh`.
################################################################################

set -e

function absolute_path {
  [[ $1 = /* ]] && echo "$1" || echo "$(pwd)/${1#./}"
}

ROOT_DIRECTORY=$(dirname "$(dirname $(absolute_path "$0"))")
SCRIPT_DIRECTORY=${ROOT_DIRECTORY}/dashboard_box

(cd $SCRIPT_DIRECTORY; git pull)
(cd $ROOT_DIRECTORY; ROOT_DIRECTORY=$ROOT_DIRECTORY $SCRIPT_DIRECTORY/run.sh)
