// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

abstract class Benchmark {
  Benchmark(this.name);

  final String name;

  Future<Null> init() => new Future.value();

  Future<num> run();

  void markLastRunWasBest(num result, List<num> allRuns);

  String toString() => name;
}

Future<num> runBenchmark(Benchmark benchmark, { int iterations: 1 }) async {
  await benchmark.init();

  List<num> allRuns = <num>[];

  num minValue;

  while (iterations > 0) {
    iterations--;

    print('');

    num result = await benchmark.run();

    allRuns.add(result);

    if (minValue == null || result < minValue) {
      benchmark.markLastRunWasBest(result, allRuns);
      minValue = result;
    }
  }

  return minValue;
}
