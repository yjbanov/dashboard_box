// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:dashboard_box/src/firebase.dart';
import 'package:dashboard_box/src/utils.dart';

String _serverUrl;

/// Usage:
///
/// From `~/flutter_dashboard` execute:
///
///     dart -c dashboard_box/bin/firebase_to_golem.dart \
///       --server=http://hostname:port \
///       --root-directory=$HOME/flutter_dashboard
///
Future<Null> main(List<String> rawArgs) async {
  ArgParser argp = new ArgParser()
    ..addOption('server')
    ..addOption('root-directory');
  ArgResults args = argp.parse(rawArgs);

  if (!args.wasParsed('server') && !args.wasParsed('root-directory')) {
    fail(
r'''
Usage:

From `~/flutter_dashboard` execute:

dart -c dashboard_box/bin/firebase_to_golem.dart \
  --server=http://hostname:port \
  --root-directory=$HOME/flutter_dashboard
'''.trim()
    );
  }

  _serverUrl = args['server'];
  config = new Config(path.normalize(path.absolute(args['root-directory'])));

  syncContinuously() async {
    await syncToGolem();
    new Future.delayed(const Duration(minutes: 1), syncContinuously);
  }

  syncContinuously();
}

/// The last git revision processed by this script used to prevent submitting
/// the same revision repeatedly.
String lastProcessedRevision;

/// Synchronizes Firebase values to Golem once.
Future<Null> syncToGolem() async {
  // TODO(yjbanov): get each individual benchmark revision as opposed to whole build revision
  Map<String, dynamic> buildInfo = await firebaseDownloadCurrent('build');
  String revision = buildInfo['revision'];
  if (lastProcessedRevision == revision) {
    // Skip this revision. Already processed it.
    return;
  }

  try {
    await updateFlutterRepo(revision);
    int golemRevision = await computeGolemRevision();
    await sendMetrics(golemRevision);
  } catch(e, s) {
    print('ERROR: $e\n$s');
  }

  lastProcessedRevision = revision;
}

/// Sends a single value to a Golem benchmark.
Future<Null> sendMetric({String firebaseKey, String metric, String golemBenchmark, int golemRevision}) async {
  checkNotNull(firebaseKey, metric, golemBenchmark, golemRevision);

  Map<String, dynamic> metricData = await firebaseDownloadCurrent(firebaseKey);
  num score = metricData[metric];

  print(
'''
Submitting:
  Metric    : $metric
  Score     : $score
  Benchmark : $golemBenchmark
  Revision  : $golemRevision
'''.trim());

  http.Response resp = await http.post(
    '${_serverUrl}/PostExternalResults',
    body: jsonEncode([
        {
          'target': 'flutter',
          'benchmark': golemBenchmark,
          'metric': 'Score',
          'revision': golemRevision,
          'score': score,

          // TODO(yjbanov): these need to change depending on device
          'cpu': 'ARMv7 Processor rev 0 (v7l) 38.40',
          'machineType': 'android-armv7',
        }
    ])
  );

  if (resp.statusCode != 200) {
    print('ERROR: server responded with HTTP ${resp.statusCode}');
    if (resp.body != null)
      print(resp.body);
  } else {
    print('INFO: Server says "${resp.body}"');
  }
}

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

/// Checks out a clean git branch of Flutter at the given [revision].
Future<Null> updateFlutterRepo(String revision) async {
  section('Updating Flutter repo');

  cd(config.rootDirectory);
  if (!exists(config.flutterDirectory))
    await exec('git', ['clone', 'https://github.com/flutter/flutter.git']);

  await inDirectory(config.flutterDirectory, () async {
    await exec('git', ['clean', '-d', '-f', '-x']);
    await exec('git', ['fetch', 'origin', 'master']);
    await exec('git', ['checkout', revision]);
  });
}

/// Sends all metrics we care about tracking over time.
Future<Null> sendMetrics(int golemRevision) async {
  print('Sending metrics to golem');

  // TODO: send analysis numbers too

  await sendMetric(
    firebaseKey: 'complex_layout_scroll_perf__timeline_summary',
    metric: 'average_frame_build_time_millis',
    golemBenchmark: 'complex_layout_scroll_perf.average_frame_build_time_millis',
    golemRevision: golemRevision
  );

  await sendMetric(
    firebaseKey: 'complex_layout_scroll_perf__timeline_summary',
    metric: 'missed_frame_build_budget_count',
    golemBenchmark: 'complex_layout_scroll_perf.missed_frame_build_budget_count',
    golemRevision: golemRevision
  );

  await sendMetric(
    firebaseKey: 'complex_layout_scroll_perf__timeline_summary',
    metric: 'worst_frame_build_time_millis',
    golemBenchmark: 'complex_layout_scroll_perf.worst_frame_build_time_millis',
    golemRevision: golemRevision
  );

  await sendMetric(
    firebaseKey: 'complex_layout__start_up',
    metric: 'timeToFirstFrameMicros',
    golemBenchmark: 'complex_layout_startup.time_to_first_frame_micros',
    golemRevision: golemRevision
  );

  await sendMetric(
    firebaseKey: 'complex_layout__start_up',
    metric: 'engineEnterTimestampMicros',
    golemBenchmark: 'complex_layout_startup.engine_enter_timestamp_micros',
    golemRevision: golemRevision
  );
}
