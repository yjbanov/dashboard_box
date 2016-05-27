// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'utils.dart';

/// Performs actual work on the dashboard build box.
typedef Future<Null> TaskCallback(Task task);

/// Represents a unit of work performed on the dashboard build box that can
/// succeed, fail and be retried independently of others.
class Task {
  Task(this.name, this.callback);

  /// The name of the task that shows up in log messages.
  ///
  /// This should be as unique as possible to avoid confusion.
  final String name;

  /// Performs actual work.
  final TaskCallback callback;
}

/// Runs a queue of tasks; collects results.
class TaskRunner {
  final List<Task> _taskQueue = <Task>[];

  void enqueue(Task task) {
    _taskQueue.add(task);
  }

  void enqueueAll(Iterable<Task> tasks) {
    _taskQueue.addAll(tasks);
  }

  Future<BuildResult> run() async {
    List<TaskResult> results = <TaskResult>[];

    for (Task task in _taskQueue) {
      section('Running task ${task.name}');
      TaskResult result;
      try {
        await task.callback(task);
        result = new TaskResult.success(task);
      } catch (error) {
        String message = '${task.name} failed: $error';
        print('');
        print(message);
        result = new TaskResult.failure(task, message);
      }
      results.add(result);
      section('Task ${task.name} ${result.succeeded ? "succeeded" : "failed"}.');
    }

    return new BuildResult(results);
  }
}

/// All results accumulated from a build session.
class BuildResult {
  BuildResult(this.results);

  /// Individual task results.
  final List<TaskResult> results;

  /// Whether the overall build failed.
  ///
  /// We consider the build as failed if at least one task fails.
  bool get failed => results.any((TaskResult res) => res.failed);

  /// The opposite of [failed], i.e. all tasks succeeded.
  bool get succeeded => !failed;

  /// The number of failed tasks.
  int get failedTaskCount => results.fold(0, (int previous, TaskResult res) => previous + (res.failed ? 1 : 0));
}

/// A result of running a single task.
class TaskResult {

  /// Constructs a successful result.
  TaskResult.success(this.task)
    : this.succeeded = true,
      this.message = 'success';

  /// Constructs an unsuccessful result.
  TaskResult.failure(this.task, this.message) : this.succeeded = false;

  /// The task that was run.
  final Task task;

  /// Whether the task succeeded.
  final bool succeeded;

  /// Whether the task failed.
  bool get failed => !succeeded;

  /// Explains the result in a human-readable format.
  final String message;
}
