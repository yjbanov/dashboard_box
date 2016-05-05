// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as path;

void fail(String message) {
  stderr.writeln(message);
  exit(1);
}

void rm(File file) {
  if (file.existsSync())
    file.deleteSync();
}

void run(List<String> args, { Directory cwd }) {
  print(args.join(' '));

  ProcessResult result = Process.runSync(args.first, args.sublist(1),
    workingDirectory: cwd?.path);

  if (result.stdout.isNotEmpty)
    print(result.stdout.trim());
  if (result.stderr.isNotEmpty)
    print(result.stderr.trim());

  if (result.exitCode != 0)
    print('exited with code ${result.exitCode}');
}

void copy(File sourceFile, Directory targetDirectory, { String name }) {
  File target = new File(path.join(targetDirectory.path, name ?? path.basename(sourceFile.path)));
  target.writeAsBytesSync(sourceFile.readAsBytesSync());
}

void section(String title) {
  print('');
  print('••• $title •••');
}

String get sdkVersion {
  String ver = Platform.version;
  if (ver.indexOf('(') != -1)
    ver = ver.substring(0, ver.indexOf('(')).trim();
  return ver;
}
