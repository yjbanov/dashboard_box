// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'framework.dart';
import 'utils.dart';

List<Task> createPerfTests() {
  return <Task>[
    new Task(
      'complex_layout_scroll_perf',
      (Task task) async {
        await runTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'test_driver/scroll_perf.dart', task.name);
      }
    )
  ];
}

List<Task> createStartupTests() => <Task>[
  createStartupTest('${config.flutterDirectory.path}/examples/flutter_gallery', 'flutter_gallery'),
  createStartupTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'complex_layout'),
];

Task createStartupTest(String testDirectory, String testName) {
  return new Task(
    testName,
    (_) => runStartupTest(testDirectory, testName)
  );
}

Future<Null> runStartupTest(String testDirectory, String testName) async {
  await inDirectory(testDirectory, () async {
    await pub('get');
    await flutter('run', options: [
      '--verbose',
      // TODO(yjbanov): switch to --profile when ready (http://dartbug.com/26550)
      '--debug',
      '--trace-startup',
      '-d',
      config.androidDeviceId
    ]);
    copy(file('$testDirectory/build/start_up_info.json'),
        config.dataDirectory, name: '${testName}__start_up.json');
  });
}

Future<int> runTest(String testDirectory, String testTarget, String testName) {
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
    copy(file('$testDirectory/build/${testName}.timeline_summary.json'),
        config.dataDirectory, name: '${testName}__timeline_summary.json');
  });
}
