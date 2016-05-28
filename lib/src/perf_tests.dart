// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'framework.dart';
import 'utils.dart';

List<Task> createPerfTests() {
  return <Task>[
    new Task(
      'complex_layout_scroll_perf__timeline_summary',
      (Task task) async {
        await _runPerfTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'test_driver/scroll_perf.dart', task.name);
      }
    )
  ];
}

List<Task> createStartupTests() => <Task>[
  _createStartupTest('${config.flutterDirectory.path}/examples/flutter_gallery', 'flutter_gallery'),
  _createStartupTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'complex_layout'),
];

Task _createStartupTest(String testDirectory, String testName) {
  return new Task(
    '${testName}__start_up',
    (_) => _runStartupTest(testDirectory, testName)
  );
}

Future<TaskResultData> _runStartupTest(String testDirectory, String testName) async {
  return await inDirectory(testDirectory, () async {
    await pub('get');
    await flutter('run', options: [
      '--verbose',
      // TODO(yjbanov): switch to --profile when ready (http://dartbug.com/26550)
      '--debug',
      '--trace-startup',
      '-d',
      config.androidDeviceId
    ]);
    return new TaskResultData.fromFile(file('$testDirectory/build/start_up_info.json'));
  });
}

Future<TaskResultData> _runPerfTest(String testDirectory, String testTarget, String testName) {
  return inDirectory(testDirectory, () async {
    await pub('get');
    await flutter('drive', options: [
      '--verbose',
      // TODO(yjbanov): switch to --profile when ready (http://dartbug.com/26550)
      '--debug',
      '--trace-startup', // Enables "endless" timeline event buffering.
      '-t',
      testTarget,
      '-d',
      config.androidDeviceId
    ]);
    return new TaskResultData.fromFile(file('$testDirectory/build/${testName}.timeline_summary.json'));
  });
}
