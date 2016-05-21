#!/bin/bash

# Fast fail the script on failures.
set -e

# Echo commands as they are run.
set -v

# Check the project.
pub global activate tuneup
pub global run tuneup check

# Re-generate the website.
pub build

# TODO: deploy to a personal staging site, based on github ID, when not
#       merging into master

if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then
  if [ "$TRAVIS_BRANCH" = "master" ]; then
    echo "Installing firebase-tools."

    npm install -g firebase-tools

    echo "Using firebase version `firebase --version`"

    echo "Deploying to Firebase."

    firebase -P purple-butterfly-3000 --token "$FIREBASE_TOKEN" deploy
  fi
fi
