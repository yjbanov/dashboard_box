// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:stack_trace/stack_trace.dart';

/// Current working directory
String cwd = Directory.current.path;
Config config;

Future<Null> main(List<String> args) async {
  Chain.capture(() {
    build(args);
  });
}

Future<Null> build(List<String> args) async {
  if (args.length != 1) {
    print('Expects a single argument pointing to the root directory of the dashboard'
      ' but got: ${args}');
    exit(1);
  }

  config = new Config(args.single);

  printSectionHeading('Build started on ${new DateTime.now()}');
  print(config);

  if (!config.dataDirectory.existsSync()) {
    config.dataDirectory.deleteSync(recursive: true);
  }
  config.dataDirectory.createSync(recursive: true);

  printSectionHeading('Get Flutter!');

  cd(config.rootDirectory);
  if (config.flutterDirectory.existsSync()) {
    config.flutterDirectory.deleteSync(recursive: true);
  }
  await exec('git', ['clone', '--depth', '1', 'https://github.com/flutter/flutter.git']);
  await flutter('config', options: ['--no-analytics']);
  await flutter('doctor');
  await flutter('update-packages');

  printSectionHeading('Run tests');

  await runTest('${config.flutterDirectory.path}/examples/stocks', 'test_driver/scroll_perf.dart', 'stocks_scroll_perf');
  await runTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'test_driver/scroll_perf.dart', 'complex_layout_scroll_perf');

  await runStartupTest('${config.flutterDirectory.path}/examples/stocks', 'stocks');
  await runStartupTest('${config.flutterDirectory.path}/dev/benchmarks/complex_layout', 'complex_layout');

  printSectionHeading('Generate dashboard');

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
    new File('${testDirectory}/build/${testName}.timeline_summary.json')
        .copySync('${config.dataDirectory.path}/${testName}__timeline_summary.json');
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
    new File('${testDirectory}/build/start_up_info.json')
        .copySync('${config.dataDirectory.path}/${testName}__start_up.json');
  });
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
  Directory dir;
  if (directory is String) {
    cwd = directory;
    dir = new Directory(directory);
  } else if (directory is Directory) {
    cwd = directory.path;
    dir = directory;
  } else {
    throw 'Unsupported type ${directory.runtimeType} of $directory';
  }

  if (!dir.existsSync()) {
    throw 'Cannot cd into directory that does not exist: $directory';
  }
}

Future<int> exec(String executable, List<String> arguments, {Map<String, String> env, bool canFail: false}) async {
  print('Executing: $executable ${arguments.join(' ')}');
  Process proc = await Process.start(executable, arguments, environment: env, workingDirectory: cwd);
  stdout.addStream(proc.stdout);
  stderr.addStream(proc.stderr);
  int exitCode = await proc.exitCode;
  if (exitCode != 0 && !canFail) {
    print('Executable failed with exit code ${exitCode}. Quitting with the same code.');
    exit(exitCode);
  }
  return exitCode;
}

Future<int> flutter(String command, {List<String> options: const<String>[]}) {
  List<String> args = [command]
    ..addAll(options);
  return exec(path.join(config.flutterDirectory.path, 'bin', 'flutter'), args);
}

Future<int> pub(String command) {
  return exec(
    path.join(config.flutterDirectory.path, 'bin/cache/dart-sdk/bin/pub'),
    [command]
  );
}

class Config {
  Config(String rootPath) : rootDirectory = new Directory(rootPath) {
    this.dashboardDirectory = new Directory('${rootDirectory.path}/dashboard');
    this.dataDirectory = new Directory('${rootDirectory.path}/dashboard_box/jekyll/_data');
    this.flutterDirectory = new Directory('${rootDirectory.path}/flutter');
    this.scriptsDirectory = new Directory('${rootDirectory.path}/dashboard_box');
    this.buildInfoFile = new File('${dataDirectory.path}/build.json');
    this.summariesFile = new File('${dataDirectory.path}/summaries.json');
    this.analysisFile = new File('${dataDirectory.path}/analysis.json');

    this.gsutil = Platform.environment['GSUTIL'];
    if (gsutil == null) {
      String home = requireEnvVar('HOME');
      gsutil = "$home/google-cloud-sdk/bin/gsutil";
    }

    configFile = new File(path.join(scriptsDirectory.path, 'config.json'));

    if (!configFile.existsSync()) {
      print('''
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
      exit(1);
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
    print('${name} environment variable is missing.');
    print('Quitting.');
    exit(1);
  }
  return value;
}

dynamic/*=T*/ requireConfigProperty(Map<String, dynamic/*<T>*/> map, String propertyName) {
  if (!map.containsKey(propertyName)) {
    print('Configuration property not found: $propertyName');
    exit(1);
  }
  return map[propertyName];
}

void printSectionHeading(String title) {
  print('-----------------------------------------');
  print(title);
  print('-----------------------------------------');
}
