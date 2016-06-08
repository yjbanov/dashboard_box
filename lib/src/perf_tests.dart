// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'framework.dart';
import 'utils.dart';

List<Task> createPerfTests() {
  return <Task>[
    new PerfTest(
      'complex_layout_scroll_perf__timeline_summary',
      '${config.flutterDirectory.path}/dev/benchmarks/complex_layout',
      'test_driver/scroll_perf.dart',
      'complex_layout_scroll_perf'
    )
  ];
}

List<Task> createStartupTests() => <Task>[
  new StartupTest('flutter_gallery__start_up', '${config.flutterDirectory.path}/examples/flutter_gallery'),
  new StartupTest('complex_layout__start_up', '${config.flutterDirectory.path}/dev/benchmarks/complex_layout'),
];

/// Measure application startup performance.
class StartupTest extends Task {

  StartupTest(String name, this.testDirectory) : super(name);

  final String testDirectory;

  Future<TaskResultData> run() async {
    return await inDirectory(testDirectory, () async {
      await pub('get', onCancel);
      await flutter('run', onCancel, options: [
        '--profile',
        '--trace-startup',
        '-d',
        config.androidDeviceId
      ]);
      return new TaskResultData.fromFile(file('$testDirectory/build/start_up_info.json'));
    });
  }
}

/// Measures application runtime performance, specifically per-frame
/// performance.
class PerfTest extends Task {

  PerfTest(String name, this.testDirectory, this.testTarget, this.timelineFileName)
      : super(name);

  final String testDirectory;
  final String testTarget;
  final String timelineFileName;

  @override
  Future<TaskResultData> run() {
    return inDirectory(testDirectory, () async {
      await pub('get', onCancel);
      await flutter('drive', onCancel, options: [
        '--profile',
        '--trace-startup', // Enables "endless" timeline event buffering.
        '-t',
        testTarget,
        '-d',
        config.androidDeviceId
      ]);
      return new TaskResultData.fromFile(file('$testDirectory/build/${timelineFileName}.timeline_summary.json'));
    });
  }
}
