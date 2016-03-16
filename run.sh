#!/bin/bash
set -e
set -x

echo "-----------------------------------------"
echo "Build started on $(date)"
echo "-----------------------------------------"

ROOT_DIRECTORY=$(dirname $(dirname $0))
DASHBOARD_DIRECTORY="$ROOT_DIRECTORY/dashboard"
FLUTTER_DIRECTORY="$ROOT_DIRECTORY/flutter"

echo "DASHBOARD_DIRECTORY: $DASHBOARD_DIRECTORY"
echo "FLUTTER_DIRECTORY: $FLUTTER_DIRECTORY"
echo "ANDROID_DEVICE_ID: $ANDROID_DEVICE_ID"

cd $ROOT_DIRECTORY
rm -rf $FLUTTER_DIRECTORY
git clone https://github.com/flutter/flutter.git

export PATH=$(pwd)/flutter/bin:$PATH
export PATH=$(pwd)/flutter/bin/cache/dart-sdk/bin:$PATH

cd $FLUTTER_DIRECTORY
flutter doctor

cd examples/stocks
pub get 1>&2
flutter drive --verbose --no-checked --target=test_driver/scroll_perf.dart --device-id=$ANDROID_DEVICE_ID

echo "-----------------------------------------"
echo "Build finished on $(date)"
echo "-----------------------------------------"
echo
