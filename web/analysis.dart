// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide Event;

import 'package:charted/charts/charts.dart';
import 'package:firebase/firebase.dart';

Firebase firebase;
CartesianArea chartArea;

Map<int, Measurement> repoMeasurements;
Map<int, Measurement> galleryMeasurements;

void main() {
  updateTimeSeriesChart('#time-series-chart');

  firebase = new Firebase("https://purple-butterfly-3000.firebaseio.com/");

  firebase.onAuth().listen((context) {
    _listenForChartChanges();
  });

  _setUpAuth();
}

void _listenForChartChanges() {
  Firebase repoAnalysis = firebase.child("measurements/analyzer_cli__analysis_time/history");
  Firebase galleryAnalysis = firebase.child("measurements/analyzer_server__analysis_time/history");

  DateTime startDate = new DateTime.now().subtract(new Duration(days: 90));

  Query repoQuery = repoAnalysis
    .orderByChild('timestamp')
    .startAt(key: 'timestamp', value: startDate.millisecondsSinceEpoch)
    .limitToLast(2000);
  Query galleryQuery = galleryAnalysis
    .orderByChild('timestamp')
    .startAt(key: 'timestamp', value: startDate.millisecondsSinceEpoch)
    .limitToLast(2000);

  repoQuery.onValue.listen((Event event) {
    repoMeasurements = {};
    event.snapshot.forEach((DataSnapshot snapshot) {
      Measurement measurement = new Measurement(snapshot.val());
      if (measurement.timestampMillis != null) {
        repoMeasurements[measurement.timestampMillis] = measurement;
      }
    });
    _updateChart();
  });
  galleryQuery.onValue.listen((Event event) {
    galleryMeasurements = {};
    event.snapshot.forEach((DataSnapshot snapshot) {
      Measurement measurement = new Measurement(snapshot.val());
      if (measurement.timestampMillis != null) {
        galleryMeasurements[measurement.timestampMillis] = measurement;
      }
    });
    _updateChart();
  });
}

void _setUpAuth() {
  document.getElementById('firebase-login').onClick.listen((_) {
    firebase.authWithOAuthPopup("google", scope: 'email');
  });

  document.getElementById('firebase-logout').onClick.listen((_) {
    firebase.unauth();
  });
}

void _updateChart() {
  if (repoMeasurements == null || galleryMeasurements == null) return;

  List<int> times = new List.from(new Set<int>()
    ..addAll(repoMeasurements.keys)
    ..addAll(galleryMeasurements.keys)
  )..sort();

  List data = times.map((int time) {
    return [time, repoMeasurements[time]?.time, galleryMeasurements[time]?.time];
  }).toList();

  updateTimeSeriesChart('#time-series-chart', data);
}

class Measurement {
  Measurement(this.map);

  final Map map;

  num get expected => map['expected'];
  num get issues => map['issues'];
  String get sdk => map['sdk'];
  num get time => map['time'];
  num get timestampMillis => map['timestamp'];

  String get commit => map['commit'];

  DateTime get date => new DateTime.fromMillisecondsSinceEpoch(timestampMillis);

  String get dateString {
    DateTime d = date;
    return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  }

  String toString() => '${time}s (${dateString})';
}

void updateTimeSeriesChart(String wrapperSelector, [List data]) {
  if (chartArea != null) {
    chartArea.data = new ChartData(_columnSpecs, data);
    chartArea.draw();
  } else {
    DivElement wrapper = document.querySelector(wrapperSelector);
    DivElement areaHost = wrapper.querySelector('.chart-host');
    DivElement legendHost = wrapper.querySelector('.chart-legend-host');

    data ??= _getPlaceholderData();

    ChartData chartData = new ChartData(_columnSpecs, data);
    ChartSeries series = new ChartSeries("Flutter Analysis Times", [1, 2], new LineChartRenderer());
    ChartConfig config = new ChartConfig([series], [0])..legend = new ChartLegend(legendHost);
    ChartState state = new ChartState();

    chartArea = new CartesianArea(
      areaHost,
      chartData,
      config,
      state: state
    );

    chartArea.addChartBehavior(new Hovercard(isMultiValue: true));
    chartArea.addChartBehavior(new AxisLabelTooltip());

    chartArea.draw();
  }
}

String _printDurationVal(num val) {
  if (val == null) return '';
  return val.toStringAsFixed(1) + 's';
}

Iterable _columnSpecs = [
  new ChartColumnSpec(
    label: 'Time',
    type: ChartColumnSpec.TYPE_TIMESTAMP
  ),
  new ChartColumnSpec(
    label: 'flutter analyze flutter-repo',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  ),
  new ChartColumnSpec(
    label: 'analysis server mega_gallery',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  )
];

Iterable _getPlaceholderData() {
  DateTime now = new DateTime.now();

  return [
    [now.subtract(new Duration(days: 30)).millisecondsSinceEpoch, 0.0, 0.0],
    [now.millisecondsSinceEpoch, 0.0, 0.0],
  ];
}
