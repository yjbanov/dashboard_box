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
  Map<String, dynamic> buildInfo = await firebaseDownloadCurrent('dashboard_bot_status');
  String revision = buildInfo['revision'];
  if (lastProcessedRevision == revision) {
    // Skip this revision. Already processed it.
    return;
  }

  try {
    await sendMetrics();
  } catch(e, s) {
    print('ERROR: $e\n$s');
  }

  lastProcessedRevision = revision;
}

/// Sends all metrics we care about tracking over time.
Future<Null> sendMetrics() async {
  print('Sending metrics to golem');

  Map<String, dynamic> data = await firebaseDownloadCurrent('golem_data');
  for (String benchmarkName in data.keys) {
    int golemRevision = data['golem_revision'];
    num score = data['score'];
    _sendMetric(benchmarkName, golemRevision, score);
  }
}

/// Sends a single value to a Golem benchmark.
Future<Null> _sendMetric(String benchmarkName, int golemRevision, num score) async {
  checkNotNull(benchmarkName, golemRevision, score);

  print(
'''
Submitting:
  Benchmark : $benchmarkName
  Revision  : $golemRevision
  Score     : $score
'''.trim());

  http.Response resp = await http.post(
    '${_serverUrl}/PostExternalResults',
    body: jsonEncode([
        {
          'target': 'flutter',
          'benchmark': benchmarkName,
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
