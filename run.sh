#!/bin/bash
set -e
set -x

function absolute_path {
  [[ $1 = /* ]] && echo "$1" || echo "$(pwd)/${1#./}"
}

function check_env_var {
  NAME=$1
  VALUE=$2
  if [[ -z "${VALUE}" ]]; then
    echo "${NAME} environment variable is missing."
    echo "Quitting."
    exit 1
  fi
}

echo "-----------------------------------------"
echo "Build started on $(date)"
echo "-----------------------------------------"

PARENT_DIRECTORY=$(dirname $(absolute_path "$0"))
ROOT_DIRECTORY=$(dirname "${PARENT_DIRECTORY}")
DASHBOARD_DIRECTORY="$ROOT_DIRECTORY/dashboard"
JEKYLL_DIRECTORY="$ROOT_DIRECTORY/dashboard_box/jekyll"
JEKYLL_BIN=${JEKYLL_BIN:-"/usr/local/bin/jekyll"}
DATA_DIRECTORY="$JEKYLL_DIRECTORY/_data"
FLUTTER_DIRECTORY="$ROOT_DIRECTORY/flutter"
SCRIPTS_DIRECTORY="$ROOT_DIRECTORY/dashboard_box"
GSUTIL=${GSUTIL:-"/Users/$USER/google-cloud-sdk/bin/gsutil"}

# The following config file must export the following variables:
#
# ANDROID_DEVICE_ID - the ID of the Android device used for performance testing,
#     can be overridden externally
# FIREBASE_FLUTTER_DASHBOARD_TOKEN - authentication token to Firebase used to
#     upload metrics
#
# Example:
#
# export ANDROID_DEVICE_ID=...
# export FIREBASE_FLUTTER_DASHBOARD_TOKEN=...
if [ ! -f "${PARENT_DIRECTORY}/config.sh" ]; then
  echo "Config file missing: ${PARENT_DIRECTORY}/config.sh"
  echo "Quitting."
  exit 1
fi

source "${PARENT_DIRECTORY}/config.sh"

check_env_var "ANDROID_DEVICE_ID" $ANDROID_DEVICE_ID
check_env_var "FIREBASE_FLUTTER_DASHBOARD_TOKEN" $FIREBASE_FLUTTER_DASHBOARD_TOKEN

BUILD_INFO_FILE="$DATA_DIRECTORY/build.json"

# TODO: remove these when we move over to Firebase for dashboard
SUMMARIES_FILE="$DATA_DIRECTORY/summaries.json"
ANALYSIS_FILE="$DATA_DIRECTORY/analysis.json"

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
git clone --depth 1 https://github.com/flutter/flutter.git

export PATH=$(pwd)/flutter/bin:$PATH
export PATH=$(pwd)/flutter/bin/cache/dart-sdk/bin:$PATH

flutter config --no-analytics
flutter doctor
flutter update-packages


# --------------------------
# Run tests
# --------------------------

function runTest {
  TEST_DIRECTORY=$1
  TEST_TARGET=$2
  TEST_NAME=$3

  cd $TEST_DIRECTORY
  pub get 1>&2
  flutter drive --verbose --no-checked --target=$TEST_TARGET --device-id=$ANDROID_DEVICE_ID
  cp build/${TEST_NAME}.timeline_summary.json $DATA_DIRECTORY/${TEST_NAME}__timeline_summary.json
}

function runStartupTest {
  TEST_DIRECTORY=$1
  TEST_NAME=$2

  cd $TEST_DIRECTORY
  pub get 1>&2
  flutter run --verbose --no-checked --trace-startup --device-id=$ANDROID_DEVICE_ID
  cp build/start_up_info.json $DATA_DIRECTORY/${TEST_NAME}__start_up.json
}

runTest $FLUTTER_DIRECTORY/examples/stocks test_driver/scroll_perf.dart stocks_scroll_perf
runTest $FLUTTER_DIRECTORY/dev/benchmarks/complex_layout test_driver/scroll_perf.dart complex_layout_scroll_perf

runStartupTest $FLUTTER_DIRECTORY/examples/stocks stocks
runStartupTest $FLUTTER_DIRECTORY/dev/benchmarks/complex_layout complex_layout

# --------------------------
# Generate dashboard
# --------------------------

mkdir -p $DASHBOARD_DIRECTORY
cd $DASHBOARD_DIRECTORY

SUMMARIES="{"
for jsonFile in $(ls $DATA_DIRECTORY/*__timeline_summary.json); do
  NAME="${jsonFile%.*}"
  SUMMARIES="${SUMMARIES} \"$(basename $NAME)\": "
  SUMMARIES="${SUMMARIES} $(cat $jsonFile)"
  SUMMARIES="${SUMMARIES},"
done
SUMMARIES="${SUMMARIES} \"blank\": {}}"
echo $SUMMARIES > $SUMMARIES_FILE

# Expecting mega to fail here. Will fix soon.

set +e

# Analyze the repo.
flutter analyze --flutter-repo --benchmark --benchmark-expected=25.0
mv analysis_benchmark.json $DATA_DIRECTORY/analyzer_cli__analysis_time.json

# Generate a large sample app.
(cd $FLUTTER_DIRECTORY; dart dev/tools/mega_gallery.dart)

# Analyze it.
pushd $FLUTTER_DIRECTORY/dev/benchmarks/mega_gallery
flutter analyze --watch --benchmark --benchmark-expected=10.0
mv analysis_benchmark.json $DATA_DIRECTORY/analyzer_server__analysis_time.json
popd

# No longer expecting anything to fail from here on out.

set -e

ANALYSIS="{ \"flutter_analyze_flutter_repo\": $(cat $DATA_DIRECTORY/analyzer_cli__analysis_time.json), "
ANALYSIS="${ANALYSIS} \"analysis_server_mega_gallery\": $(cat $DATA_DIRECTORY/analyzer_server__analysis_time.json) }"
echo $ANALYSIS > $ANALYSIS_FILE

echo "{" > ${BUILD_INFO_FILE}
echo "\"build_timestamp\": \"$(date)\"," >> ${BUILD_INFO_FILE}
echo "\"dart_version\": \"$(dart --version 2>&1 | sed "s/\"/'/g")\"" >> ${BUILD_INFO_FILE}
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

if [[ "$UPLOAD_DASHBOARD_DATA" == "yes" ]]; then
  $GSUTIL -m rsync -d -R -p $DASHBOARD_DIRECTORY gs://flutter-dashboard
  $GSUTIL -m acl ch -R -g 'google.com:R' gs://flutter-dashboard/current
  $GSUTIL -m acl ch -R -u 'goog.flutter.dashboard@gmail.com:R' gs://flutter-dashboard/current

  cd src/firebase_uploader
  pub get
  cd ../..

  set +e

  shopt -s nullglob
  for f in $DATA_DIRECTORY/*.json ; do
    echo "Uploading $f to Firebase"
    dart ${ROOT_DIRECTORY}/dashboard_box/src/firebase_uploader/bin/uploader.dart $f
  done

  set -e
fi

echo "-----------------------------------------"
echo "Build finished on $(date)"
echo "-----------------------------------------"
echo
