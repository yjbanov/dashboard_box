// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'framework.dart';
import 'utils.dart';

Task createGalleryTest() {
  return new Task(
    'flutter_gallery__transition_perf',
    (_) async {
      Directory galleryDirectory = dir('${config.flutterDirectory.path}/examples/flutter_gallery');
      await inDirectory(galleryDirectory, () async {
        await pub('get');
        await flutter('drive', options: [
          '--verbose',
          // TODO(yjbanov): switch to --profile when ready (http://dartbug.com/26550)
          '--debug',
          '--trace-startup',
          '-t',
          'test_driver/transitions_perf.dart',
          '-d',
          config.androidDeviceId,
        ]);
      });

      // Route paths contains slashes, which Firebase doesn't accept in keys, so we
      // remove them.
      Map<String, dynamic> original = JSON.decode(file('${galleryDirectory.path}/build/transition_durations.timeline.json').readAsStringSync());
      Map<String, dynamic> clean = new Map.fromIterable(
        original.keys,
        key: (String key) => key.replaceAll('/', ''),
        value: (String key) => original[key]
      );

      file('${config.dataDirectory.path}/flutter_gallery__transition_perf.json')
        .writeAsStringSync(JSON.encode(clean));
    }
  );
}
