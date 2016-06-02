// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

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

    await build();

    section('Build finished on ${new DateTime.now()}');
  }, onError: (error, Chain chain) {
    print(error);
    print(chain.terse);
    exit(1);
  });
}

Future<Null> build() async {
  prepareDataDirectory();

  String revision = await getLatestGreenRevision();
  if (hasAlreadyRun(revision)) {
    print('No new green revisions found to run. Will check back again soon.');
    await markBuildCancelled();
    return null;
  }

  await getFlutter(revision);

  DateTime timestamp = await getFlutterRepoCommitTimestamp(revision);
  String sdk = await getDartVersion();
  section('build info');
  print('revision : $revision');
  print('timestamp: $timestamp');
  print('sdk      : $sdk');

  TaskRunner runner = new TaskRunner(revision)
    ..enqueueAll(createPerfTests())
    ..enqueueAll(createStartupTests())
    ..enqueue(createGalleryTest())
    ..enqueueAll(createAnalyzerTests(sdk: sdk, commit: revision, timestamp: timestamp))
    ..enqueue(createRefreshTest());

  BuildResult result = await runner.run();
  section('Build results');
  print('Ran ${result.results.length} tasks (${result.failedTaskCount} failed):');
  for (TaskResult taskResult in result.results)
    print('  ${taskResult.task.name} ${taskResult.succeeded ? "succeeded" : "failed"}');

  await generateBuildInfoFile(revision, result);
  await uploadDataToFirebase(result);
  markAsRan(revision);
}

void prepareDataDirectory() {
  rrm(config.dataDirectory);
  mkdirs(config.dataDirectory);
}

/// Existence of this file in the data directory indicates that the last build
/// attempt was cancelled because there was nothing new to build, usually due
/// lack of new green revisions of Flutter.
File get buildCancelledMarkerFile => file('${config.dataDirectory.path}/build_cancelled');

void markBuildCancelled() {
  buildCancelledMarkerFile.writeAsStringSync('');
}

final Directory tempDirectory = dir('${Platform.environment['HOME']}/.flutter_dashboard');

File _revisionMarkerFile(String revision) {
  mkdirs(tempDirectory);
  return file('${tempDirectory.path}/flutter-dashboard-revision-$revision');
}

bool hasAlreadyRun(String revision) => _revisionMarkerFile(revision).existsSync();

void markAsRan(String revision) {
  if (!shouldUploadData)
    return;

  _revisionMarkerFile(revision).writeAsStringSync(new DateTime.now().toString());
}

Future<Null> generateBuildInfoFile(String revision, BuildResult result) async {
  Map<String, dynamic> buildInfo = <String, dynamic>{
    'build_timestamp': '${new DateTime.now()}',
    'dart_version': await getDartVersion(),
    'revision': revision,
    'success': result.succeeded,
    'failed_task_count': result.failedTaskCount,
  };
  await config.dashboardBotStatusFile.writeAsString(jsonEncode(buildInfo));
}

bool get shouldUploadData => Platform.environment['UPLOAD_DASHBOARD_DATA'] == 'yes';

Future<Null> uploadDataToFirebase(BuildResult result) async {
  for (TaskResult taskResult in result.results) {
    // TODO(devoncarew): We should also upload the fact that these tasks failed.
    if (taskResult.data == null)
      continue;

    Map<String, dynamic> data = new Map<String, dynamic>.from(taskResult.data.json);

    Map<String, dynamic> metadata = <String, dynamic>{
      'success': taskResult.succeeded,
      'revision': taskResult.revision,
      'message': taskResult.message,
    };

    data['__metadata__'] = metadata;
    await file('${config.dataDirectory.path}/${taskResult.task.name}.json')
      .writeAsString(jsonEncode(data));
  }

  if (!shouldUploadData)
    return null;

  for (File file in ls(config.dataDirectory)) {
    if (!file.path.endsWith('.json'))
      continue;

    await uploadToFirebase(file);
  }
}
