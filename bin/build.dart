// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:stack_trace/stack_trace.dart';

import 'package:dashboard_box/src/analysis.dart';
import 'package:dashboard_box/src/buildbot.dart';
import 'package:dashboard_box/src/firebase.dart';
import 'package:dashboard_box/src/framework.dart';
import 'package:dashboard_box/src/gallery.dart';
import 'package:dashboard_box/src/perf_tests.dart';
import 'package:dashboard_box/src/refresh.dart';
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

  String commit = await getFlutterRepoCommit();
  DateTime timestamp = await getFlutterRepoCommitTimestamp(commit);
  String sdk = await getDartVersion();
  section('build info');
  print('commit   : $commit');
  print('timestamp: $timestamp');
  print('sdk      : $sdk');
  await prepareDataDirectory();

  TaskRunner runner = new TaskRunner()
    ..enqueueAll(createPerfTests())
    ..enqueueAll(createStartupTests())
    ..enqueue(createGalleryTest())
    ..enqueueAll(createAnalyzerTests(sdk: sdk, commit: commit, timestamp: timestamp))
    ..enqueue(createRefreshTest());

  BuildResult result = await runner.run();
  section('Build results');
  print('Ran ${result.results.length} tasks (${result.failedTaskCount} failed):');
  for (TaskResult taskResult in result.results)
    print('  ${taskResult.task.name} ${taskResult.succeeded ? "succeeded" : "failed"}');

  Map<String, dynamic> buildInfo = await generateBuildInfo(revision, result);

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

Future<Map<String, dynamic>> generateBuildInfo(String revision, BuildResult result) async {
  Map<String, dynamic> buildInfo = <String, dynamic>{
    'build_timestamp': '${new DateTime.now()}',
    'dart_version': await getDartVersion(),
    'revision': revision,
    'success': result.succeeded,
    'failed_task_count': result.failedTaskCount,
  };
  await config.dashboardBotStatusFile.writeAsString(jsonEncode(buildInfo));
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
