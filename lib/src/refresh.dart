// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'benchmarks.dart';
import 'framework.dart';
import 'utils.dart';

Task createRefreshTest({
  String sdk,
  String commit,
  DateTime timestamp
}) {
  return new Task(
    'mega_gallery__refresh_time',
    (_) async {
      Benchmark benchmark = new EditRefreshBenchmark(sdk, commit, timestamp);
      section(benchmark.name);
      await runBenchmark(benchmark, iterations: 3);
      return benchmark.bestResult;
    }
  );
}

class EditRefreshBenchmark extends Benchmark {
  EditRefreshBenchmark(this.sdk, this.commit, this.timestamp) : super('edit refresh');

  final String sdk;
  final String commit;
  final DateTime timestamp;

  Directory get megaDir => dir(path.join(config.flutterDirectory.path, 'dev/benchmarks/mega_gallery'));
  File get benchmarkFile => file(path.join(megaDir.path, 'refresh_benchmark.json'));

  @override
  TaskResultData get lastResult => new TaskResultData.fromFile(benchmarkFile);

  Future<Null> init() {
    return inDirectory(config.flutterDirectory, () async {
      await dart(['dev/tools/mega_gallery.dart']);
    });
  }

  @override
  Future<num> run() async {
    rm(benchmarkFile);
    int exitCode = await inDirectory(megaDir, () async {
      return await flutter('run', options: ['-d', config.androidDeviceId, '--resident', '--benchmark'], canFail: true);
    });
    if (exitCode != 0)
      return new Future.error(exitCode);
    return addBuildInfo(benchmarkFile, timestamp: timestamp, expected: 200, sdk: sdk, commit: commit);
  }
}
