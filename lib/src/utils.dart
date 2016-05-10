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

void rm(FileSystemEntity entity) {
  if (entity.existsSync())
    entity.deleteSync();
}

/// Remove recursively.
void rrm(FileSystemEntity entity) {
  if (entity.existsSync())
    entity.deleteSync(recursive: true);
}

List<FileSystemEntity> ls(Directory directory) => directory.listSync();

Directory dir(String path) => new Directory(path);

File file(String path) => new File(path);

void copy(File sourceFile, Directory targetDirectory, { String name }) {
  File target = file(path.join(targetDirectory.path, name ?? path.basename(sourceFile.path)));
  target.writeAsBytesSync(sourceFile.readAsBytesSync());
}

FileSystemEntity move(FileSystemEntity whatToMove, { Directory to, String name }) {
  return whatToMove.renameSync(path.join(to.path, name ?? path.basename(whatToMove.path)));
}

/// Equivalent of `mkdir directory`.
void mkdir(Directory directory) {
  directory.createSync();
}

/// Equivalent of `mkdir -p directory`.
void mkdirs(Directory directory) {
  directory.createSync(recursive: true);
}

bool exists(FileSystemEntity entity) => entity.existsSync();

void section(String title) {
  print('');
  print('••• $title •••');
}

Future<String> getDartVersion() async {
  // The Dart SDK return the version text to stderr.
  ProcessResult result = Process.runSync(dartBin, ['--version']);
  String version = result.stderr.trim();
  if (version.indexOf('(') != -1)
    version = version.substring(0, version.indexOf('(')).trim();
  return version.replaceAll('"', "'");
}

Future<String> getFlutterRepoCommit() {
  return inDirectory(config.flutterDirectory, () {
    return eval('git', ['rev-parse', 'HEAD']);
  });
}

Future<DateTime> getFlutterRepoCommitTimestamp(String commit) {
  // git show -s --format=%at 4b546df7f0b3858aaaa56c4079e5be1ba91fbb65
  return inDirectory(config.flutterDirectory, () async {
    String unixTimestamp = await eval('git', ['show', '-s', '--format=%at', commit]);
    int secondsSinceEpoch = int.parse(unixTimestamp);
    return new DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  });
}

/// Executes a command and returns its exit code.
Future<int> exec(String executable, List<String> arguments, {Map<String, String> env, bool canFail: false}) async {
  print('Executing: $executable ${arguments.join(' ')}');
  Process proc = await Process.start(executable, arguments, environment: env, workingDirectory: cwd);
  proc.stdout
    .transform(UTF8.decoder)
    .transform(const LineSplitter())
    .listen(print);
  proc.stderr
    .transform(UTF8.decoder)
    .transform(const LineSplitter())
    .listen(stderr.writeln);
  int exitCode = await proc.exitCode;

  if (exitCode != 0 && !canFail)
    fail('Executable failed with exit code ${exitCode}.');

  return exitCode;
}

/// Executes a command and returns its standard output as a String.
Future<String> eval(String executable, List<String> arguments, {Map<String, String> env, bool canFail: false}) async {
  print('Executing: $executable ${arguments.join(' ')}');
  Process proc = await Process.start(executable, arguments, environment: env, workingDirectory: cwd);
  stderr.addStream(proc.stderr);
  String output = await UTF8.decodeStream(proc.stdout);
  int exitCode = await proc.exitCode;

  if (exitCode != 0 && !canFail)
    fail('Executable failed with exit code ${exitCode}.');

  return output.trimRight();
}

Future<int> flutter(String command, {List<String> options: const<String>[]}) {
  List<String> args = [command]
    ..addAll(options);
  return exec(path.join(config.flutterDirectory.path, 'bin', 'flutter'), args);
}

String get dartBin => path.join(config.flutterDirectory.path, 'bin/cache/dart-sdk/bin/dart');

Future<int> dart(List<String> args) => exec(dartBin, args);

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

  if (!d.existsSync())
    throw 'Cannot cd into directory that does not exist: $directory';
}

class Config {
  Config(String rootPath) : rootDirectory = dir(rootPath) {
    this.dataDirectory = dir('${rootDirectory.path}/data');
    this.backupDirectory = dir('${rootDirectory.path}/backup');
    this.flutterDirectory = dir('${rootDirectory.path}/flutter');
    this.scriptsDirectory = dir('${rootDirectory.path}/dashboard_box');

    this.buildInfoFile = file('${dataDirectory.path}/build.json');

    configFile = file(path.join(scriptsDirectory.path, 'config.json'));

    if (!configFile.existsSync()) {
      fail('''
Configuration file not found: ${configFile.path}

See: https://github.com/flutter/dashboard_box/blob/master/README.md
'''.trim());
    }

    Map<String, dynamic> configJson = JSON.decode(configFile.readAsStringSync());
    androidDeviceId = requireConfigProperty(configJson, 'android_device_id');
    firebaseFlutterDashboardToken = requireConfigProperty(configJson, 'firebase_flutter_dashboard_token');
  }

  final Directory rootDirectory;
  Directory dataDirectory;
  Directory backupDirectory;
  Directory flutterDirectory;
  Directory scriptsDirectory;
  File configFile;
  File buildInfoFile;
  String androidDeviceId;
  String firebaseFlutterDashboardToken;

  @override
  String toString() =>
'''
rootDirectory: $rootDirectory
dataDirectory: $dataDirectory
backupDirectory: $backupDirectory
flutterDirectory: $flutterDirectory
scriptsDirectory: $scriptsDirectory
configFile: $configFile
buildInfoFile: $buildInfoFile
androidDeviceId: $androidDeviceId
'''.trim();
}

String requireEnvVar(String name) {
  String value = Platform.environment[name];

  if (value == null)
    fail('${name} environment variable is missing. Quitting.');

  return value;
}

dynamic/*=T*/ requireConfigProperty(Map<String, dynamic/*<T>*/> map, String propertyName) {
  if (!map.containsKey(propertyName))
    fail('Configuration property not found: $propertyName');

  return map[propertyName];
}

String jsonEncode(dynamic data) {
  return new JsonEncoder.withIndent('  ').convert(data) + '\n';
}
