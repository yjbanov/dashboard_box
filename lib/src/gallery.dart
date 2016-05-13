// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'utils.dart';

Future<Null> runGalleryTests() async {
  Directory galleryDirectory = dir('${config.flutterDirectory.path}/examples/flutter_gallery');
  await inDirectory(galleryDirectory, () async {
    await pub('get');
    await flutter('drive', options: [
      '--verbose',
      '--no-checked',
      '--trace-startup',
      '-t',
      'test_driver/transitions_perf.dart',
      '-d',
      config.androidDeviceId,
    ]);
  });

  copy(file('${galleryDirectory.path}/build/transition_durations.timeline.json'), config.dataDirectory,
    name: 'flutter_gallery__transtition_perf.json');
}
