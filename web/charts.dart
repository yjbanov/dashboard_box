// Copyright (c) 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide Event;

import 'package:charted/charts/charts.dart';
import 'package:firebase/firebase.dart';

Firebase firebase;
CartesianArea analysisChartArea;
CartesianArea refreshChartArea;

Map<int, Measurement> repoMeasurements = {};
Map<int, Measurement> galleryMeasurements = {};
Map<int, Measurement> refreshMeasurements = {};

void main() {
  _updateAnalysisChart();
  _updateRefreshChart();

  firebase = new Firebase("https://purple-butterfly-3000.firebaseio.com/");
  firebase.onAuth().listen((context) {
    _listenForChartChanges();
  });
}

void _listenForChartChanges() {
  Firebase repoAnalysis = firebase.child("measurements/analyzer_cli__analysis_time/history");
  Firebase galleryAnalysis = firebase.child("measurements/analyzer_server__analysis_time/history");
  Firebase refreshTimes = firebase.child("measurements/mega_gallery__refresh_time/history");

  DateTime startDate = new DateTime.now().subtract(new Duration(days: 90));

  Query repoQuery = repoAnalysis
    .orderByChild('timestamp')
    .startAt(key: 'timestamp', value: startDate.millisecondsSinceEpoch)
    .limitToLast(2000);
  Query galleryQuery = galleryAnalysis
    .orderByChild('timestamp')
    .startAt(key: 'timestamp', value: startDate.millisecondsSinceEpoch)
    .limitToLast(2000);
  Query refreshQuery = refreshTimes
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
  refreshQuery.onValue.listen((Event event) {
    refreshMeasurements = {};
    event.snapshot.forEach((DataSnapshot snapshot) {
      Measurement measurement = new Measurement(snapshot.val());
      if (measurement.timestampMillis != null) {
        refreshMeasurements[measurement.timestampMillis] = measurement;
      }
    });
    _updateChart();
  });
}

void _updateChart() {
  List<int> times = new List.from(new Set<int>()
    ..addAll(repoMeasurements.keys)
    ..addAll(galleryMeasurements.keys)
  )..sort();

  List analysisData = times.map((int time) {
    return [time, repoMeasurements[time]?.time, galleryMeasurements[time]?.time];
  }).toList();

  _updateAnalysisChart(analysisData);

  List refreshData = [];
  for (int time in refreshMeasurements.keys.toList()..sort())
    refreshData = [time, refreshMeasurements[time]];
  _updateRefreshChart(refreshData);
}

class Measurement {
  Measurement(this.map);

  final Map map;

  num get expected => map['expected'];
  num get issues => map['issues'];
  String get sdk => map['sdk'];
  num get time => map['time'];
  num get timestampMillis => map['timestamp'];

  String get commit => map['commit'] is String ? map['commit'] : null;

  DateTime get date => new DateTime.fromMillisecondsSinceEpoch(timestampMillis);

  String get dateString {
    DateTime d = date;
    return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
  }

  String toString() => '${time}s (${dateString})';
}

void _updateAnalysisChart([List data = const []]) {
  if (data.length < 2)
    data = _getPlaceholderData();

  if (analysisChartArea != null) {
    analysisChartArea.data = new ChartData(_analysisColumnSpecs, data);
  } else {
    DivElement wrapper = document.querySelector('#analysis-perf-chart');
    DivElement areaHost = wrapper.querySelector('.chart-host');
    DivElement legendHost = wrapper.querySelector('.chart-legend-host');

    ChartData chartData = new ChartData(_analysisColumnSpecs, data);
    ChartSeries series = new ChartSeries("Flutter Analysis Times", [1, 2], new LineChartRenderer());
    ChartConfig config = new ChartConfig([series], [0])..legend = new ChartLegend(legendHost);

    analysisChartArea = new CartesianArea(
      areaHost,
      chartData,
      config,
      state: new ChartState()
    );

    analysisChartArea.addChartBehavior(new Hovercard(builder: (int columnIndex, int rowIndex) {
      List row = analysisChartArea.data.rows.elementAt(rowIndex);
      ChartColumnSpec spec = analysisChartArea.data.columns.elementAt(columnIndex);
      int time = row[0];
      Measurement measurement = (columnIndex == 1 ? repoMeasurements : galleryMeasurements)[time];
      return _createTooltip(spec, measurement);
    }));
    analysisChartArea.addChartBehavior(new AxisLabelTooltip());
  }

  analysisChartArea.draw();
}

void _updateRefreshChart([List data = const []]) {
  if (data.length < 2)
    data = _getPlaceholderDataRefresh();

  if (refreshChartArea != null) {
    refreshChartArea.data = new ChartData(_refreshColumnSpecs, data);
  } else {
    DivElement wrapper = document.querySelector('#refresh-perf-chart');
    DivElement areaHost = wrapper.querySelector('.chart-host');
    DivElement legendHost = wrapper.querySelector('.chart-legend-host');

    ChartData chartData = new ChartData(_refreshColumnSpecs, data);
    ChartSeries series = new ChartSeries("Edit Refresh Times", [1], new LineChartRenderer());
    ChartConfig config = new ChartConfig([series], [0])..legend = new ChartLegend(legendHost);

    refreshChartArea = new CartesianArea(
      areaHost,
      chartData,
      config,
      state: new ChartState()
    );

    refreshChartArea.addChartBehavior(new Hovercard(builder: (int columnIndex, int rowIndex) {
      List row = refreshChartArea.data.rows.elementAt(rowIndex);
      ChartColumnSpec spec = refreshChartArea.data.columns.elementAt(columnIndex);
      int time = row[0];
      Measurement measurement = refreshMeasurements[time];
      _createTooltip(spec, measurement);
    }));
    refreshChartArea.addChartBehavior(new AxisLabelTooltip());
  }

  refreshChartArea.draw();
}

String _printDurationVal(num val) {
  if (val == null) return '';
  return val.toStringAsFixed(1) + 's';
}

Element _createTooltip(ChartColumnSpec spec, Measurement measurement) {
  Element element = div('', className: 'hovercard-single');

  if (measurement == null) {
    element.text = 'No data';
  } else {
    element.children.add(div(spec.label, className: 'hovercard-title'));
    element.children.add(div('time: ${measurement.time}s', className: 'hovercard-value'));
    element.children.add(div('at: ${measurement.date}', className: 'hovercard-value'));
    if (measurement.commit != null)
      element.children.add(div('commit: ${measurement.commit.substring(0, 10)}', className: 'hovercard-value'));
  }

  return element;
}

List _analysisColumnSpecs = [
  new ChartColumnSpec(
    label: 'Time',
    type: ChartColumnSpec.TYPE_TIMESTAMP
  ),
  new ChartColumnSpec(
    label: 'flutter_repo',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  ),
  new ChartColumnSpec(
    label: 'mega_gallery',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  )
];

List _refreshColumnSpecs = [
  new ChartColumnSpec(
    label: 'Time',
    type: ChartColumnSpec.TYPE_TIMESTAMP
  ),
  new ChartColumnSpec(
    label: 'Refresh',
    type: ChartColumnSpec.TYPE_NUMBER,
    formatter: _printDurationVal
  )
];

List _getPlaceholderData() {
  DateTime now = new DateTime.now();

  return [
    [now.subtract(new Duration(days: 30)).millisecondsSinceEpoch, 0.0, 0.0],
    [now.millisecondsSinceEpoch, 0.0, 0.0],
  ];
}

List _getPlaceholderDataRefresh() {
  DateTime now = new DateTime.now();

  return [
    [now.subtract(new Duration(days: 30)).millisecondsSinceEpoch, 0.0],
    [now.millisecondsSinceEpoch, 0.0],
  ];
}

DivElement div(String text, { String className }) {
  DivElement element = new DivElement()..text = text;
  if (className != null)
    element.className = className;
  return element;
}
