import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/imports/resmed_night_catalog.dart';
import '../../core/nights/night_signal_reader.dart';
import '../../core/nights/night_timeline.dart';
import '../../core/parser/edf_header_parser.dart';
import '../../core/parser/edf_signal_reader.dart';
import '../charts/simple_line_chart.dart';

class NightViewerScreen extends StatefulWidget {
  const NightViewerScreen({
    super.key,
    required this.night,
  });

  final ResmedNightSummary night;

  @override
  State<NightViewerScreen> createState() => _NightViewerScreenState();
}

class _NightViewerScreenState extends State<NightViewerScreen> {
  NightTimeline? _timeline;
  EdxEdfHeader? _refHeader;

  bool _loading = true;
  String? _error;

  String? _selectedLabel;
  String? _selectedUnit;

  int _windowSeconds = 30;
  int _startSeconds = 0;

  bool _loadingSeries = false;
  List<EdfDataPoint> _points = [];
  String? _seriesInfo;

  String _fmtClock(DateTime dt, {bool withSeconds = false}) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (!withSeconds) return '$hh:$mm';
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<int?> _estimateTotalSeconds(File edfFile) async {
    try {
      final header = await EdfHeaderParser.parseHeader(edfFile);

      final bytesPerRecord =
          header.signals.fold<int>(0, (sum, s) => sum + s.samplesPerRecord) * 2;

      final fileLen = await edfFile.length();
      final dataBytes = fileLen - header.headerBytes;
      final computedRecords = dataBytes > 0 ? (dataBytes ~/ bytesPerRecord) : 0;

      final totalRecords = header.numRecords > 0
          ? min(header.numRecords, computedRecords)
          : computedRecords;

      final totalSeconds = (totalRecords * header.recordDurationSeconds).floor();
      return totalSeconds > 0 ? totalSeconds : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final night = widget.night;
      final nightStart = night.start;

      // Header de référence: segment principal (souvent PLD)
      final refFile = night.primarySegment.bestFile;
      final refHeader = await EdfHeaderParser.parseHeader(refFile);

      final defaultIdx = EdfSignalReader.findSignalIndex(refHeader);
      final defaultLabel = refHeader.signals[defaultIdx].label.trim();
      final defaultUnit = refHeader.signals[defaultIdx].physicalDimension.trim();

      // Construire timeline: offsets + durations
      final segs = <NightTimelineSegment>[];

      for (final s in night.segments) {
        final dur = s.totalSeconds ?? await _estimateTotalSeconds(s.bestFile) ?? 0;
        final off = max(0, s.start.difference(nightStart).inSeconds);
        segs.add(
          NightTimelineSegment(
            session: s,
            offsetSeconds: off,
            durationSeconds: max(0, dur),
          ),
        );
      }

      final fallbackTotal = max(0, night.end.difference(nightStart).inSeconds);
      final timeline = NightTimeline.build(
        nightStart: nightStart,
        segments: segs,
        fallbackTotalSeconds: fallbackTotal,
      );

      if (!mounted) return;
      setState(() {
        _timeline = timeline;
        _refHeader = refHeader;
        _selectedLabel = defaultLabel;
        _selectedUnit = defaultUnit;
        _windowSeconds = 30;
        _startSeconds = 0;
        _loading = false;
      });

      await _reloadWindow();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reloadWindow() async {
    final timeline = _timeline;
    final label = _selectedLabel;

    if (timeline == null || label == null || label.isEmpty) return;

    final maxStart = max(0, timeline.totalSeconds - _windowSeconds);
    final clampedStart = _startSeconds.clamp(0, maxStart);
    if (clampedStart != _startSeconds) _startSeconds = clampedStart;

    setState(() {
      _loadingSeries = true;
      _seriesInfo = 'Chargement…';
      _points = [];
    });

    try {
      final res = await NightSignalReader.readWindow(
        timeline: timeline,
        globalStartSeconds: _startSeconds,
        windowSeconds: _windowSeconds,
        signalLabel: label,
        maxPoints: 3000,
      );

      if (!mounted) return;

      final startDt = timeline.nightStart.add(Duration(seconds: _startSeconds));
      final endDt = timeline.nightStart.add(
        Duration(seconds: min(timeline.totalSeconds, _startSeconds + _windowSeconds)),
      );

      setState(() {
        _loadingSeries = false;
        _points = res.points;
        _selectedUnit = res.unit;

        _seriesInfo =
        '${res.label} • ${res.points.length} pts • ${_fmtClock(startDt, withSeconds: _windowSeconds <= 30)} → ${_fmtClock(endDt, withSeconds: _windowSeconds <= 30)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSeries = false;
        _points = [];
        _seriesInfo = 'Lecture impossible: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night;
    final timeline = _timeline;

    final title = 'Nuit complète ${_fmtDate(night.nightDate)}';

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || timeline == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Erreur: ${_error ?? "timeline nulle"}'),
          ),
        ),
      );
    }

    final maxStart = max(0, timeline.totalSeconds - _windowSeconds);
    final step = 60;
    final snapped = (_startSeconds ~/ step) * step;
    final current = snapped.clamp(0, maxStart);

    final divisions = maxStart == 0 ? 1 : max(1, (maxStart / step).round());

    final startDt = timeline.nightStart.add(Duration(seconds: current));
    final endDt = timeline.nightStart.add(
      Duration(seconds: min(timeline.totalSeconds, current + _windowSeconds)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Segments: ${night.segmentsCount}'),
                  Text('Fenêtre nuit: ${_fmtClock(night.start)} → ${_fmtClock(night.end)}'),
                  const SizedBox(height: 10),
                  if (_seriesInfo != null) Text(_seriesInfo!),
                  if (_loadingSeries) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Signal
          if (_refHeader != null) ...[
            DropdownButtonFormField<String>(
              value: _selectedLabel,
              decoration: const InputDecoration(
                labelText: 'Signal',
                border: OutlineInputBorder(),
              ),
              items: _refHeader!.signals.map((s) {
                final unit = s.physicalDimension.trim().isEmpty ? '—' : s.physicalDimension.trim();
                final label = s.label.trim();
                return DropdownMenuItem(
                  value: label,
                  child: Text('$label ($unit)'),
                );
              }).toList(growable: false),
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _selectedLabel = v);
                await _reloadWindow();
              },
            ),
            const SizedBox(height: 12),
          ],

          // Fenêtre
          DropdownButtonFormField<int>(
            value: _windowSeconds,
            decoration: const InputDecoration(
              labelText: 'Fenêtre',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 secondes')),
              DropdownMenuItem(value: 120, child: Text('2 minutes')),
              DropdownMenuItem(value: 300, child: Text('5 minutes')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _windowSeconds = v);
              await _reloadWindow();
            },
          ),

          const SizedBox(height: 12),

          // Slider global
          Text(
            'Début: ${_fmtClock(startDt, withSeconds: false)} / ${_fmtClock(timeline.nightStart.add(Duration(seconds: timeline.totalSeconds)), withSeconds: false)}',
          ),
          Slider(
            value: current.toDouble(),
            min: 0,
            max: maxStart.toDouble(),
            divisions: divisions,
            label: _fmtClock(startDt),
            onChanged: maxStart == 0
                ? null
                : (v) {
              setState(() {
                _startSeconds = ((v / step).round() * step).toInt();
              });
            },
            onChangeEnd: maxStart == 0 ? null : (_) async => _reloadWindow(),
          ),

          const SizedBox(height: 12),

          // Chart
          SimpleLineChart(
            title: _selectedLabel ?? 'Signal',
            unit: _selectedUnit,
            points: _points,
            xOrigin: timeline.nightStart,
            xMin: current.toDouble(),
            xMax: (current + _windowSeconds).toDouble(),
          ),
        ],
      ),
    );
  }
}
