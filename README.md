# Scripts for Flutter's performance lab and dashboard

This repository contains scripts for the job that generates data for the
dashboard.

To test this script locally:

- Get a Mac with a recent Mac OS X
- Clone this repository _exactly_ into `~/flutter_dashboard/dashboard_box`, so
  that the `run.sh` script could be found _exactly_ at
  `~/flutter_dashboard/dashboard_box/run.sh`
- For better results, make sure there's nothing else in `~/flutter_dashboard`
- Complete the [Flutter Setup](https://flutter.io/setup/), if you haven't
  already. Note, however, that this job will install its own copy of Flutter.
- Connect an Android device
- Set `ANDROID_DEVICE_ID_OVERRIDE` environment variable to the ID of your device
  as reported by `flutter devices` command (this is because the ID of the device
  connected to the box is not the same as yours)
- Launch the job `launchctl start job.plist`

If `launchd` was able to run the script, you will be able to find the output in
`/tmp/flutter.dashboard.stdout` (standard output) and in
`/tmp/flutter.dashboard.stderr` (standard error).
