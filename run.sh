#!/bin/bash
set -e
set -x

DART_SDK=${DART_SDK:-"/usr/local/opt/dart/libexec"}

cd ${ROOT_DIRECTORY}/dashboard_box
$DART_SDK/bin/pub get
$DART_SDK/bin/dart bin/build.dart $ROOT_DIRECTORY
