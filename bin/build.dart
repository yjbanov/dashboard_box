// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:stack_trace/stack_trace.dart';

import 'package:dashboard_box/src/analysis.dart';
import 'package:dashboard_box/src/buildbot.dart';
import 'package:dashboard_box/src/firebase_uploader.dart';
import 'package:dashboard_box/src/utils.dart';

Future<Null> main(List<String> args) async {
  if (args.length != 1)
    fail('Expects a single argument pointing to the root directory of the dashboard but got: $args');

  config = new Config(path.normalize(path.absolute(args.single)));

  Chain.capture(() async {
    section('Build started on ${new DateTime.now()}');
    print(config);

    if (!exists(config.dataDirectory))
      rrm(config.dataDirectory);

    mkdirs(config.dataDirectory);

    await build();

    section('Build finished on ${new DateTime.now()}');
  }, onError: (error, Chain chain) {
    print(error);
    print(chain.terse);
    exit(1);
  });
}

Future<Null> build() async {
  String revision = await getLatestGreenRevision();
  if (hasAlreadyRun(revision)) {
    print('No new green revisions found to run. Will check back again soon.');
    return null;
  }

  await getFlutter(revision);
  await prepareDataDirectory();
  await runPerfTests();
  await runStartupTests();
  await runAnalyzerTests();
  Map<String, dynamic> buildInfo = await generateBuildInfo(revision);
  await uploadDataToFirebase();

  markAsRan(revision, buildInfo);
}

final Directory tempDirectory = dir('${Platform.environment['HOME']}/.flutter_dashboard');

File _revisionMarkerFile(String revision) {
  mkdirs(tempDirectory);
  return file('${tempDirectory.path}/flutter-dashboard-revision-$revision');
}

bool hasAlreadyRun(String revision) => _revisionMarkerFile(revision).existsSync();

void markAsRan(String revision, Map<String, dynamic> buildInfo) {
  if (!shouldUploadData)
    return;

  _revisionMarkerFile(revision).writeAsStringSync(jsonEncode(buildInfo));
}

Future<Null> prepareDataDirectory() async {
  // Backup old data
  if (!exists(config.backupDirectory))
    mkdirs(config.backupDirectory);

  if (exists(config.dataDirectory)) {
    DateFormat dfmt = new DateFormat('yyyy-MM-dd-HHmmss');
    String nameWithTimestamp = dfmt.format(new DateTime.now());
    move(config.dataDirectory, to: config.backupDirectory, name: nameWithTimestamp);
  }

  mkdir(config.dataDirectory);
}

Future<Null> getFlutter(String revision) async {
  section('Get Flutter!');

  cd(config.rootDirectory);
  if (exists(config.flutterDirectory))
    rrm(config.flutterDirectory);

  await exec('git', ['clone', 'https://github.com/flutter/flutter.git']);
  await inDirectory(config.flutterDirectory, () async {
    await exec('git', ['checkout', revision]);
  });
  await flutter('config', options: ['--no-analytics']);

  section('flutter doctor');
  await flutter('doctor');

  section('flutter update-packages');
  await flutter('update-packages');
}

Future<Null> runPerfTests() async {
  section('Run perf tests');

  await runTest('${config.flutterDirectory.path}/examples/stocks', 'test_driver/scroll_perf.dart', 'stocks_scroll_perf');
  await runTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'test_driver/scroll_perf.dart', 'complex_layout_scroll_perf');
}

Future<Null> runStartupTests() async {
  section('Run startup tests');

  await runStartupTest('${config.flutterDirectory.path}/examples/stocks', 'stocks');
  await runStartupTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'complex_layout');
}

Future<int> runTest(String testDirectory, String testTarget, String testName) {
  return inDirectory(testDirectory, () async {
    await pub('get');
    await flutter('drive', options: [
      '--verbose',
      '--no-checked',
      '--trace-startup', // Enables "endless" timeline event buffering.
      '-t',
      testTarget,
      '-d',
      config.androidDeviceId
    ]);
    copy(file('$testDirectory/build/${testName}.timeline_summary.json'),
        config.dataDirectory, name: '${testName}__timeline_summary.json');
  });
}

Future<int> runStartupTest(String testDirectory, String testName) {
  return inDirectory(testDirectory, () async {
    await pub('get');
    await flutter('run', options: [
      '--verbose',
      '--no-checked',
      '--trace-startup',
      '-d',
      config.androidDeviceId
    ]);
    copy(file('$testDirectory/build/start_up_info.json'),
        config.dataDirectory, name: '${testName}__start_up.json');
  });
}

Future<Map<String, dynamic>> generateBuildInfo(String revision) async {
  Map<String, dynamic> buildInfo = <String, dynamic>{
    'build_timestamp': '${new DateTime.now()}',
    'dart_version': await getDartVersion(),
    'revision': revision,
  };
  await config.buildInfoFile.writeAsString(jsonEncode(buildInfo));
  return buildInfo;
}

bool get shouldUploadData => Platform.environment['UPLOAD_DASHBOARD_DATA'] == 'yes';

Future<Null> uploadDataToFirebase() async {
  if (!shouldUploadData)
    return null;

  for (File file in ls(config.dataDirectory)) {
    await uploadToFirebase(file);
  }
}
