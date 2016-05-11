// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'package:firebase_rest/firebase_rest.dart';
import 'package:path/path.dart' as path;

import 'utils.dart';

const firebaseBaseUrl = 'https://purple-butterfly-3000.firebaseio.com';

Firebase _measurements() {
  var firebaseToken = config.firebaseFlutterDashboardToken;
  return new Firebase(Uri.parse("$firebaseBaseUrl/measurements"),
      auth: firebaseToken);
}

Future<Null> uploadToFirebase(File measurementJson) async {
  if (!measurementJson.path.endsWith('.json'))
    fail("Error: path must be to a JSON file ending in .json");

  if (!exists(measurementJson))
    fail("Error: $measurementJson not found");

  var measurementKey = path.basenameWithoutExtension(measurementJson.path);
  print('Uploading $measurementJson to key $measurementKey');

  var ref = _measurements();

  await ref
      .child(measurementKey)
      .child('current')
      .set(JSON.decode(measurementJson.readAsStringSync()));

  await ref
      .child(measurementKey)
      .child('history')
      .push(JSON.decode(measurementJson.readAsStringSync()));
}

Future<Map<String, dynamic>> firebaseDownloadCurrent(String measurementKey) async {
  DataSnapshot snapshot = await _measurements()
      .child(measurementKey)
      .child('current')
      .get();

  if (!snapshot.exists)
    return null;

  return snapshot.val as Map<String, dynamic>;
}
