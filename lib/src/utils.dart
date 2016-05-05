// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Virtual current working directory, which affect functions, such as [exec].
String cwd = Directory.current.path;

Config config;

void fail(String message) {
  stderr.writeln(message);
  exit(1);
}

void rm(File file) {
  if (file.existsSync())
    file.deleteSync();
}

Directory dir(String path) => new Directory(path);
File file(String path) => new File(path);

void copy(File sourceFile, Directory targetDirectory, { String name }) {
  File target = file(path.join(targetDirectory.path, name ?? path.basename(sourceFile.path)));
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

Future<int> exec(String executable, List<String> arguments, {Map<String, String> env, bool canFail: false}) async {
  print('Executing: $executable ${arguments.join(' ')}');
  Process proc = await Process.start(executable, arguments, environment: env, workingDirectory: cwd);
  stdout.addStream(proc.stdout);
  stderr.addStream(proc.stderr);
  int exitCode = await proc.exitCode;
  if (exitCode != 0 && !canFail) {
    fail('Executable failed with exit code ${exitCode}.');
  }
  return exitCode;
}

Future<int> flutter(String command, {List<String> options: const<String>[]}) {
  List<String> args = [command]
    ..addAll(options);
  return exec(path.join(config.flutterDirectory.path, 'bin', 'flutter'), args);
}

Future<int> dart(List<String> args) {
  return exec(
    path.join(config.flutterDirectory.path, 'bin/cache/dart-sdk/bin/dart'),
    args
  );
}

Future<int> pub(String command) {
  return exec(
    path.join(config.flutterDirectory.path, 'bin/cache/dart-sdk/bin/pub'),
    [command]
  );
}

Future<dynamic> inDirectory(dynamic directory, Future<dynamic> action()) async {
  String previousCwd = cwd;
  try {
    cd(directory);
    return await action();
  } finally {
    cd(previousCwd);
  }
}

void cd(dynamic directory) {
  Directory d;
  if (directory is String) {
    cwd = directory;
    d = dir(directory);
  } else if (directory is Directory) {
    cwd = directory.path;
    d = directory;
  } else {
    throw 'Unsupported type ${directory.runtimeType} of $directory';
  }

  if (!d.existsSync()) {
    throw 'Cannot cd into directory that does not exist: $directory';
  }
}

class Config {
  Config(String rootPath) : rootDirectory = dir(rootPath) {
    this.dashboardDirectory = dir('${rootDirectory.path}/dashboard');
    this.dataDirectory = dir('${rootDirectory.path}/dashboard_box/jekyll/_data');
    this.flutterDirectory = dir('${rootDirectory.path}/flutter');
    this.scriptsDirectory = dir('${rootDirectory.path}/dashboard_box');
    this.buildInfoFile = file('${dataDirectory.path}/build.json');
    this.summariesFile = file('${dataDirectory.path}/summaries.json');
    this.analysisFile = file('${dataDirectory.path}/analysis.json');

    this.gsutil = Platform.environment['GSUTIL'];
    if (gsutil == null) {
      String home = requireEnvVar('HOME');
      gsutil = "$home/google-cloud-sdk/bin/gsutil";
    }

    configFile = file(path.join(scriptsDirectory.path, 'config.json'));

    if (!configFile.existsSync()) {
      fail('''
Configuration file not found: ${configFile.path}

The config file must be a JSON file defining the following variables:

ANDROID_DEVICE_ID - the ID of the Android device used for performance testing, can be overridden externally
FIREBASE_FLUTTER_DASHBOARD_TOKEN - authentication token to Firebase used to upload metrics

Example:

{
  "ANDROID_DEVICE_ID": "...",
  "FIREBASE_FLUTTER_DASHBOARD_TOKEN": "..."
}
      '''.trim());
    }

    Map<String, dynamic> configJson = JSON.decode(configFile.readAsStringSync());
    androidDeviceId = requireConfigProperty(configJson, 'android_device_id');
    firebaseFlutterDashboardToken = requireConfigProperty(configJson, 'firebase_flutter_dashboard_token');
  }

  final Directory rootDirectory;
  Directory dashboardDirectory;
  Directory dataDirectory;
  Directory flutterDirectory;
  Directory scriptsDirectory;
  File configFile;
  File buildInfoFile;
  File summariesFile;
  File analysisFile;
  String gsutil;
  String androidDeviceId;
  String firebaseFlutterDashboardToken;

  @override
  String toString() =>
'''
rootDirectory: $rootDirectory
dashboardDirectory: $dashboardDirectory
dataDirectory: $dataDirectory
flutterDirectory: $flutterDirectory
scriptsDirectory: $scriptsDirectory
configFile: $configFile
buildInfoFile: $buildInfoFile
summariesFile: $summariesFile
analysisFile: $analysisFile
gsutil: $gsutil
androidDeviceId: $androidDeviceId
firebaseFlutterDashboardToken: $firebaseFlutterDashboardToken
'''.trim();
}

String requireEnvVar(String name) {
  String value = Platform.environment[name];
  if (value == null) {
    fail('${name} environment variable is missing. Quitting.');
  }
  return value;
}

dynamic/*=T*/ requireConfigProperty(Map<String, dynamic/*<T>*/> map, String propertyName) {
  if (!map.containsKey(propertyName)) {
    fail('Configuration property not found: $propertyName');
  }
  return map[propertyName];
}
