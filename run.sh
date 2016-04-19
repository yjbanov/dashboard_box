#!/bin/bash
set -e
set -x

function absolute_path {
  [[ $1 = /* ]] && echo "$1" || echo "$(pwd)/${1#./}"
}

echo "-----------------------------------------"
echo "Build started on $(date)"
echo "-----------------------------------------"

# The ID of the Android device used for performance testing, can be overridden
# externally
export ANDROID_DEVICE_ID=${ANDROID_DEVICE_ID:-"AG860440G62GIGC"}

ROOT_DIRECTORY=$(absolute_path "$(dirname $(dirname $0))")
DASHBOARD_DIRECTORY="$ROOT_DIRECTORY/dashboard"
JEKYLL_DIRECTORY="$ROOT_DIRECTORY/dashboard_box/jekyll"
JEKYLL_BIN=${JEKYLL_BIN:-"/usr/local/bin/jekyll"}
DATA_DIRECTORY="$JEKYLL_DIRECTORY/_data"
FLUTTER_DIRECTORY="$ROOT_DIRECTORY/flutter"
SCRIPTS_DIRECTORY="$ROOT_DIRECTORY/dashboard_box"
GSUTIL=${GSUTIL:-"/Users/$USER/google-cloud-sdk/bin/gsutil"}

BUILD_INFO_FILE="$DATA_DIRECTORY/build.json"
SUMMARIES_FILE="$DATA_DIRECTORY/summaries.json"

echo "ROOT_DIRECTORY: $ROOT_DIRECTORY"
echo "DASHBOARD_DIRECTORY: $DASHBOARD_DIRECTORY"
echo "DATA_DIRECTORY: $DATA_DIRECTORY"
echo "FLUTTER_DIRECTORY: $FLUTTER_DIRECTORY"
echo "ANDROID_DEVICE_ID: $ANDROID_DEVICE_ID"
echo "GSUTIL: $GSUTIL"
echo "Jekyll version: $($JEKYLL_BIN --version)"

if [[ -d $DATA_DIRECTORY ]]; then
  rm -rf $DATA_DIRECTORY
fi
mkdir -p $DATA_DIRECTORY


# --------------------------
# Get Flutter
# --------------------------

cd $ROOT_DIRECTORY
rm -rf $FLUTTER_DIRECTORY
git clone https://github.com/flutter/flutter.git

export PATH=$(pwd)/flutter/bin:$PATH
export PATH=$(pwd)/flutter/bin/cache/dart-sdk/bin:$PATH

flutter doctor


# --------------------------
# Run tests
# --------------------------

function runTest {
  TEST_DIRECTORY=$1
  TEST_TARGET=$2

  cd $TEST_DIRECTORY
  pub get 1>&2
  flutter drive --verbose --no-checked --target=$TEST_TARGET --device-id=$ANDROID_DEVICE_ID
  cp build/*.timeline_summary.json $DATA_DIRECTORY
}

runTest $FLUTTER_DIRECTORY/examples/stocks test_driver/scroll_perf.dart
runTest $FLUTTER_DIRECTORY/dev/benchmarks/complex_layout test_driver/scroll_perf.dart


# --------------------------
# Generate dashboard
# --------------------------

mkdir -p $DASHBOARD_DIRECTORY
cd $DASHBOARD_DIRECTORY

SUMMARIES="{"
for jsonFile in $(ls $DATA_DIRECTORY/*.timeline_summary.json); do
  NAME="${jsonFile%.*}"
  NAME="${NAME%.*}"
  SUMMARIES="${SUMMARIES} \"$(basename $NAME)\": "
  SUMMARIES="${SUMMARIES} $(cat $jsonFile)"
  SUMMARIES="${SUMMARIES},"
done
SUMMARIES="${SUMMARIES} \"blank\": {}}"
echo $SUMMARIES > $SUMMARIES_FILE

echo "{" > ${BUILD_INFO_FILE}
echo "\"build_timestamp\": \"$(date)\"" >> ${BUILD_INFO_FILE}
echo "}" >> ${BUILD_INFO_FILE}

if [[ -d tmp ]]; then
  rm -rf tmp
fi
$JEKYLL_BIN build --config $JEKYLL_DIRECTORY/_config_prod.yml --source $JEKYLL_DIRECTORY --destination tmp/

if [[ -d current ]]; then
  TIMESTAMP=$(date +"%y-%m-%d-%H%M%S")
  mv current $TIMESTAMP
fi

mv tmp current

$GSUTIL -m rsync -d -R -p $DASHBOARD_DIRECTORY gs://flutter-dashboard
$GSUTIL -m acl ch -R -g 'google.com:R' gs://flutter-dashboard/current
$GSUTIL -m acl ch -R -u 'goog.flutter.dashboard@gmail.com:R' gs://flutter-dashboard/current

echo "-----------------------------------------"
echo "Build finished on $(date)"
echo "-----------------------------------------"
echo
