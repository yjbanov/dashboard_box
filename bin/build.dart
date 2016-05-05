// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:stack_trace/stack_trace.dart';

import 'package:dashboard_box/src/utils.dart';

Future<Null> main(List<String> args) async {
  if (args.length != 1) {
    fail('Expects a single argument pointing to the root directory of the dashboard but got: ${args}');
  }

  config = new Config(args.single);

  Chain.capture(() {
    build();
  });
}

Future<Null> build() async {
  section('Build started on ${new DateTime.now()}');
  print(config);

  if (!config.dataDirectory.existsSync()) {
    config.dataDirectory.deleteSync(recursive: true);
  }
  config.dataDirectory.createSync(recursive: true);

  await getFlutter();
  await runPerfTests();
  await runStartupTests();
  await runAnalyzerTests();

  section('Generate dashboard');

  config.dashboardDirectory.createSync(recursive: true);
  cd(config.dashboardDirectory);

  Map<String, dynamic> summaries = <String, dynamic>{};
  config.dataDirectory.listSync().forEach((FileSystemEntity entity) async {
    if (entity is! File || !entity.path.endsWith('__timeline_summary.json'))
      return;

    File file = entity;
    Map<String, dynamic> timelineSummary = JSON.decode(await file.readAsString());
    summaries[path.basenameWithoutExtension(file.path)] = timelineSummary;
  });
  await config.summariesFile.writeAsString(JSON.encode(summaries));
}

Future<Null> getFlutter() async {
  section('Get Flutter!');

  cd(config.rootDirectory);
  if (config.flutterDirectory.existsSync()) {
    config.flutterDirectory.deleteSync(recursive: true);
  }
  await exec('git', ['clone', '--depth', '1', 'https://github.com/flutter/flutter.git']);
  await flutter('config', options: ['--no-analytics']);
  await flutter('doctor');
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
      '-t',
      testTarget,
      '-d',
      config.androidDeviceId
    ]);
    copy(file('${testDirectory}/build/${testName}.timeline_summary.json'),
        dir('${config.dataDirectory.path}'), name: '${testName}__timeline_summary.json');
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
    file('${testDirectory}/build/start_up_info.json')
        .copySync('${config.dataDirectory.path}/${testName}__start_up.json');
  });
}

Future<Null> runAnalyzerTests() async {
  DateTime now = new DateTime.now();

  section('flutter analyze --flutter-repo');
  File benchmark = file(path.join(config.flutterDirectory.path, 'analysis_benchmark.json'));
  rm(benchmark);
  await inDirectory(config.flutterDirectory, () async {
    await flutter('analyze', options: ['--flutter-repo', '--benchmark']);
  });

  _patchupAnalysisResult(benchmark, now, expected: 25.0);
  copy(benchmark, config.dataDirectory, name: 'analyzer_cli__analysis_time.json');

  section('analysis server mega_gallery');
  Directory megaDir = dir(path.join(config.flutterDirectory.path, 'dev/benchmarks/mega_gallery'));
  benchmark = file(path.join(megaDir.path, 'analysis_benchmark.json'));
  rm(benchmark);
  await inDirectory(config.flutterDirectory, () async {
    await dart(['dev/tools/mega_gallery.dart']);
  });
  await inDirectory(megaDir, () async {
    await flutter('analyze', options: ['--watch', '--benchmark']);
  });
  _patchupAnalysisResult(benchmark, now, expected: 10.0);
  copy(benchmark, config.dataDirectory, name: 'analyzer_server__analysis_time.json');
}

void _patchupAnalysisResult(File jsonFile, DateTime now, { double expected }) {
  Map<String, dynamic> json;
  if (jsonFile.existsSync()) {
    json = JSON.decode(jsonFile.readAsStringSync());
  } else {
    json = <String, dynamic>{};
  }
  json['timestamp'] = now.millisecondsSinceEpoch;
  json['sdk'] = sdkVersion;
  if (expected != null)
    json['expected'] = expected;
  jsonFile.writeAsStringSync(new JsonEncoder.withIndent('  ').convert(json) + '\n');
}
