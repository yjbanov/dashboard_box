#!/bin/bash
set -e
set -x

function clean_up {
  pushd $ROOT_DIRECTORY
  ABSOLUTE_ROOT_DIRECTORY=`pwd`

  set +e
  killall adb
  set -e
  ps -e -o pid,command | grep $ABSOLUTE_ROOT_DIRECTORY | grep -v grep | grep -v setup.sh | grep -v run.sh | cut -d' ' -f1 | xargs kill

  popd
}

DART_SDK=${DART_SDK:-"/usr/local/opt/dart/libexec"}

clean_up

# Run
cd ${ROOT_DIRECTORY}/dashboard_box
$DART_SDK/bin/pub get
$DART_SDK/bin/dart bin/build.dart $ROOT_DIRECTORY

clean_up
