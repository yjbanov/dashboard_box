// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'utils.dart';

/// Benchmark names registered in Golem.
///
/// This list must be in-sync with benchmarks listed in `flutterBenchmarks`
/// variable defined in
/// https://chrome-internal.googlesource.com/golem/+/master/config/benchmarks.dart
const registeredBenchmarkScoreKeys = const <String>[
  'complex_layout__start_up.engineEnterTimestampMicros',
  'complex_layout__start_up.timeToFirstFrameMicros',
  'complex_layout_scroll_perf__timeline_summary.average_frame_build_time_millis',
  'complex_layout_scroll_perf__timeline_summary.missed_frame_build_budget_count',
  'complex_layout_scroll_perf__timeline_summary.worst_frame_build_time_millis',

  'flutter_gallery__start_up.engineEnterTimestampMicros',
  'flutter_gallery__start_up.timeToFirstFrameMicros',
];

/// Computes a golem-compliant revision number.
///
/// Golem does not understand git commit hashes. It needs a monotonically
/// increasing integer number as the revision (Subversion legacy).
Future<int> computeGolemRevision() async {
  String gitRevs = await inDirectory(config.flutterDirectory, () async {
    return eval('git', ['rev-list', 'origin/master', '--topo-order', '--first-parent', 'origin/master']);
  });
  return gitRevs.split('\n').length;
}
