# Scripts for Flutter's performance lab and dashboard

[![Build Status](https://travis-ci.org/flutter/dashboard_box.svg?branch=master)](https://travis-ci.org/flutter/dashboard_box)

This repository contains scripts for the job that generates data for the
dashboard.

## To test this script locally

- Get a Mac with a recent Mac OS X.
- Clone this repository _exactly_ into `~/flutter_dashboard/dashboard_box`, so
  that the `run.sh` script could be found _exactly_ at
  `~/flutter_dashboard/dashboard_box/run.sh`.
- For better results, make sure there's nothing else in `~/flutter_dashboard`.
- Complete the [Flutter Setup](https://flutter.io/setup/), if you haven't
  already. Note, however, that this job will install its own copy of Flutter.
- Connect an Android device.
- Create `config.json` file in `dashboard_box` directory.
- Launch `run.sh`.

On the actual build box `launchd` writes standard output in
`/tmp/flutter.dashboard.stdout` and `/tmp/flutter.dashboard.stderr`.

## config.json

The config file must be a JSON file under `dashboard_box` and define the
following variables:

 * `android_device_id` - the ID of the Android device used for performance
   testing
 * `firebase_flutter_dashboard_token` - authentication token to Firebase used to
   upload metrics (not needed for local testing)

Example:

```json
{
  "android_device_id": "...",
  "firebase_flutter_dashboard_token": "..."
}
```

## To re-build the web site

Run `pub build`. The output will be placed in `build/web/`; this is the location
that firebase deploys from.
