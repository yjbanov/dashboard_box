#!/bin/bash
set -e
set -x

function absolute_path {
  [[ $1 = /* ]] && echo "$1" || echo "$(pwd)/${1#./}"
}

PARENT_DIRECTORY=$(dirname $(absolute_path "$0"))
ROOT_DIRECTORY=$(dirname "${PARENT_DIRECTORY}")
DASHBOARD_DIRECTORY="$ROOT_DIRECTORY/dashboard"
JEKYLL_DIRECTORY="$ROOT_DIRECTORY/dashboard_box/jekyll"
JEKYLL_BIN=${JEKYLL_BIN:-"/usr/local/bin/jekyll"}
DATA_DIRECTORY="$JEKYLL_DIRECTORY/_data"
FLUTTER_DIRECTORY="$ROOT_DIRECTORY/flutter"
SCRIPTS_DIRECTORY="$ROOT_DIRECTORY/dashboard_box"
GSUTIL=${GSUTIL:-"/Users/$USER/google-cloud-sdk/bin/gsutil"}

(cd ${ROOT_DIRECTORY}/dashboard_box; pub get)

# Run performance benchmarks
dart $SCRIPTS_DIRECTORY/bin/build.dart $ROOT_DIRECTORY
# Run the analysis benchmarks.
(dart $SCRIPTS_DIRECTORY/bin/analysis_benchmarks.dart --flutter-directory=$FLUTTER_DIRECTORY --data-directory=$DATA_DIRECTORY)

ANALYSIS="{ \"flutter_analyze_flutter_repo\": $(cat $DATA_DIRECTORY/analyzer_cli__analysis_time.json), "
ANALYSIS="${ANALYSIS} \"analysis_server_mega_gallery\": $(cat $DATA_DIRECTORY/analyzer_server__analysis_time.json) }"
echo $ANALYSIS > "$DATA_DIRECTORY/analysis.json"

BUILD_INFO_FILE="$DATA_DIRECTORY/build.json"
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

  set +e

  shopt -s nullglob
  for f in $DATA_DIRECTORY/*.json ; do
    if [[ ( "$f" == *analysis.json ) || ( "$f" == *summaries.json )]] ; then
      continue
    fi
    dart ${ROOT_DIRECTORY}/dashboard_box/bin/firebase_uploader.dart $f
  done

  set -e
fi

echo "-----------------------------------------"
echo "Build finished on $(date)"
echo "-----------------------------------------"
echo
