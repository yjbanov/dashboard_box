// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON, JsonEncoder;
import 'dart:io';

import 'package:args/args.dart';
import 'package:dashboard_box/src/utils.dart';
import 'package:path/path.dart' as path;

main(List<String> args) async {
  ArgParser parser = new ArgParser();
  parser.addOption('flutter-directory');
  parser.addOption('data-directory');
  parser.addFlag('help', abbr: 'h', negatable: false);
  ArgResults results = parser.parse(args);

  if (results['help']) {
    print(parser.usage);
    exit(0);
  }

  if (results['flutter-directory'] == null || results['data-directory'] == null)
    fail(parser.usage);

  Directory flutterDirectory = new Directory(results['flutter-directory']);
  Directory dataDirectory = new Directory(results['data-directory']);
  DateTime now = new DateTime.now();

  section('flutter analyze --flutter-repo');
  File benchmark = new File(path.join(flutterDirectory.path, 'analysis_benchmark.json'));
  rm(benchmark);
  run(['flutter', 'analyze', '--flutter-repo', '--benchmark'], cwd: flutterDirectory);
  _patchupJson(benchmark, now, expected: 25.0);
  copy(benchmark, dataDirectory, name: 'analyzer_cli__analysis_time.json');

  section('analysis server mega_gallery');
  Directory megaDir = new Directory(path.join(flutterDirectory.path, 'dev/benchmarks/mega_gallery'));
  benchmark = new File(path.join(megaDir.path, 'analysis_benchmark.json'));
  rm(benchmark);
  run(['dart', 'dev/tools/mega_gallery.dart'], cwd: flutterDirectory);
  run(['flutter', 'analyze', '--watch', '--benchmark'], cwd: megaDir);
  _patchupJson(benchmark, now, expected: 10.0);
  copy(benchmark, dataDirectory, name: 'analyzer_server__analysis_time.json');
}

void _patchupJson(File jsonFile, DateTime now, { double expected }) {
  dynamic json = JSON.decode(jsonFile.readAsStringSync());
  json['timestamp'] = now.millisecondsSinceEpoch;
  json['sdk'] = sdkVersion;
  if (expected != null)
    json['expected'] = expected;
  jsonFile.writeAsStringSync(new JsonEncoder.withIndent('  ').convert(json) + '\n');
}
