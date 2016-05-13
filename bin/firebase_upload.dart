// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'package:args/args.dart';

import 'package:dashboard_box/src/firebase.dart';
import 'package:dashboard_box/src/utils.dart';

/// A CLI utility for one-off uploading of data to Firebase.
///
/// Usage:
///
///     dart bin/firebase_upload.dart \
///       -m measurementKey \
///       -f /path/to/data/to/upload \
///       -t flutter_auth_token
///
Future<Null> main(List<String> rawArgs) async {
  ArgParser argp = new ArgParser()
    ..addOption('measurement-key', abbr: 'm')
    ..addOption('data-file', abbr: 'f')
    ..addOption('token', abbr: 't');
  ArgResults args = argp.parse(rawArgs);

  if (!args.wasParsed('measurement-key') && !args.wasParsed('data-file') && !args.wasParsed('token')) {
    fail(
r'''
Usage:

     dart bin/firebase_upload.dart \
       -m measurementKey \
       -f /path/to/data/to/upload \
       -t flutter_auth_token
'''.trim()
    );
  }

  String measurementKey = args['measurement-key'];
  File dataFile = file(args['data-file']);
  config = new Config.fromProperties(
    firebaseFlutterDashboardToken: args['token']
  );

  Map<String, dynamic> original = JSON.decode(dataFile.readAsStringSync());
  Map<String, dynamic> data = new Map.fromIterable(
    original.keys,
    key: (String key) => key.replaceAll('/', ''),
    value: (String key) => original[key]
  );

  uploadMeasurementToFirebase(measurementKey, data);
}
