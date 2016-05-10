// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'benchmarks.dart';
import 'utils.dart';

Future<Null> runAnalyzerTests() async {
  DateTime now = new DateTime.now();
  String sdk = await getDartVersion();
  String commit = await getFlutterRepoCommit();

  Benchmark benchmark = new FlutterAnalyzeBenchmark(now, sdk, commit);
  section(benchmark.name);
  await runBenchmark(benchmark, iterations: 3);

  benchmark = new FlutterAnalyzeAppBenchmark(now, sdk, commit);
  section(benchmark.name);
  await runBenchmark(benchmark, iterations: 3);
}

class FlutterAnalyzeBenchmark extends Benchmark {
  FlutterAnalyzeBenchmark(this.time, this.sdk, this.commit) : super('flutter analyze --flutter-repo');

  final DateTime time;
  final String sdk;
  final String commit;

  File get benchmarkFile => file(path.join(config.flutterDirectory.path, 'analysis_benchmark.json'));

  @override
  Future<num> run() async {
    rm(benchmarkFile);
    await inDirectory(config.flutterDirectory, () async {
      await flutter('analyze', options: ['--flutter-repo', '--benchmark']);
    });
    return _patchupResult(benchmarkFile, time, expected: 25.0, sdk: sdk, commit: commit);
  }

  @override
  void markLastRunWasBest(num result, List<num> allRuns) {
    copy(benchmarkFile, config.dataDirectory, name: 'analyzer_cli__analysis_time.json');
  }
}

class FlutterAnalyzeAppBenchmark extends Benchmark {
  FlutterAnalyzeAppBenchmark(this.time, this.sdk, this.commit) : super('analysis server mega_gallery');

  final DateTime time;
  final String sdk;
  final String commit;

  Directory get megaDir => dir(path.join(config.flutterDirectory.path, 'dev/benchmarks/mega_gallery'));
  File get benchmarkFile => file(path.join(megaDir.path, 'analysis_benchmark.json'));

  Future<Null> init() {
    return inDirectory(config.flutterDirectory, () async {
      await dart(['dev/tools/mega_gallery.dart']);
    });
  }

  @override
  Future<num> run() async {
    rm(benchmarkFile);
    await inDirectory(megaDir, () async {
      await flutter('analyze', options: ['--watch', '--benchmark']);
    });
    return _patchupResult(benchmarkFile, time, expected: 10.0, sdk: sdk, commit: commit);
  }

  @override
  void markLastRunWasBest(num result, List<num> allRuns) {
    copy(benchmarkFile, config.dataDirectory, name: 'analyzer_server__analysis_time.json');
  }
}

num _patchupResult(File jsonFile, DateTime now, {
  double expected,
  String sdk,
  String commit
}) {
  Map<String, dynamic> json;
  if (jsonFile.existsSync())
    json = JSON.decode(jsonFile.readAsStringSync());
  else
    json = <String, dynamic>{};

  json['timestamp'] = now.millisecondsSinceEpoch;
  if (expected != null)
    json['expected'] = expected;
  if (sdk != null)
    json['sdk'] = sdk;
  if (commit != null)
    json['commit'] = expected;
  jsonFile.writeAsStringSync(jsonEncode(json));

  return json['time'];
}
