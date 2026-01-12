import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/imports/resmed_night_catalog.dart';
import '../../core/nights/night_signal_reader.dart';
import '../../core/nights/night_timeline.dart';
import '../../core/nights/night_window_cache.dart';
import '../../core/nights/time_viewport.dart';
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

  final _cache = NightWindowCache(maxEntries: 140);

  // viewport continu
  late TimeViewport _vp;

  // multi-signaux (2–4)
  List<String> _selectedLabels = [];
  final Map<String, NightWindowReadResult> _seriesByLabel = {};

  bool _loadingSeries = false;
  String? _seriesInfo;

  // perf / debounce / stale-requests
  Timer? _reloadDebounce;
  int _requestId = 0;

  Timer? _persistDebounce;

  // gestures
  double _plotWidthPx = 1;
  double _scaleStartSpan = 300;
  double _scaleStartCenter = 0;
  double _scaleStartFocalX = 0;

  String _fmtClock(DateTime dt, {bool withSeconds = false}) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (!withSeconds) return '$hh:$mm';
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String get _prefsPrefix => 'viewer:${widget.night.nightKey}:';

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
    _vp = TimeViewport(centerSeconds: 0, spanSeconds: 300);
    _init();
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
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

      // Construire timeline
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

      // restore prefs (si dispo)
      final prefs = await SharedPreferences.getInstance();

      final savedLabels = prefs.getStringList('${_prefsPrefix}labels');
      final savedCenter = prefs.getDouble('${_prefsPrefix}center');
      final savedSpan = prefs.getDouble('${_prefsPrefix}span');
      final savedCursor = prefs.getDouble('${_prefsPrefix}cursor');

      // labels valides seulement
      final allLabels = refHeader.signals.map((s) => s.label.trim()).toSet();
      final restoredLabels = (savedLabels ?? const <String>[])
          .where((l) => allLabels.contains(l))
          .toList();

      final labels = restoredLabels.isNotEmpty ? restoredLabels : <String>[defaultLabel];

      // viewport par défaut: 5 minutes centré vers le début
      final initSpan = (savedSpan != null && savedSpan > 0)
          ? savedSpan
          : 300.0;

      final initCenter = (savedCenter != null)
          ? savedCenter
          : min(timeline.totalSeconds.toDouble(), 600.0);

      _vp = TimeViewport(
        centerSeconds: initCenter,
        spanSeconds: initSpan,
        cursorSeconds: savedCursor,
      );
      _vp.clampTo(0, timeline.totalSeconds.toDouble());

      if (!mounted) return;
      setState(() {
        _timeline = timeline;
        _refHeader = refHeader;
        _selectedLabels = labels.take(6).toList();
        _loading = false;
      });

      _scheduleReload(immediate: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), () async {
      final t = _timeline;
      if (t == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('${_prefsPrefix}labels', _selectedLabels);
      await prefs.setDouble('${_prefsPrefix}center', _vp.centerSeconds);
      await prefs.setDouble('${_prefsPrefix}span', _vp.spanSeconds);
      if (_vp.cursorSeconds != null) {
        await prefs.setDouble('${_prefsPrefix}cursor', _vp.cursorSeconds!);
      } else {
        await prefs.remove('${_prefsPrefix}cursor');
      }
    });
  }

  void _scheduleReload({bool immediate = false}) {
    _reloadDebounce?.cancel();
    if (immediate) {
      _reloadViewport();
      return;
    }
    _reloadDebounce = Timer(const Duration(milliseconds: 60), _reloadViewport);
  }

  String _cacheKey({
    required String label,
    required double start,
    required double span,
    required int maxPoints,
  }) {
    // bucketisation pour stabiliser les clés (évite un cache inutilement énorme)
    final bucketStep = max(1.0, span * 0.25);
    final startBucket = (start / bucketStep).floor();
    final spanBucket = (span / 0.5).round(); // 0.5s granularity
    return '${widget.night.nightKey}|$label|sb=$startBucket|sp=$spanBucket|mp=$maxPoints';
  }

  int _computeMaxPoints() {
    // règle simple: ~6 points par pixel, clamp
    final v = (_plotWidthPx * 6).round();
    return v.clamp(2000, 20000);
  }

  Future<void> _reloadViewport() async {
    final timeline = _timeline;
    if (timeline == null) return;
    if (_selectedLabels.isEmpty) return;

    _vp.clampTo(0, timeline.totalSeconds.toDouble());

    final start = _vp.start;
    final end = _vp.end;
    final span = max(1e-6, end - start);

    final maxPoints = _computeMaxPoints();
    final thisReq = ++_requestId;

    setState(() {
      _loadingSeries = true;
      _seriesInfo = 'Chargement…';
    });

    try {
      final futures = _selectedLabels.map((label) async {
        final key = _cacheKey(label: label, start: start, span: span, maxPoints: maxPoints);
        return _cache.getOrLoad(key, () {
          return NightSignalReader.readWindowF(
            timeline: timeline,
            globalStartSeconds: start,
            windowSeconds: span,
            signalLabel: label,
            maxPoints: maxPoints,
          );
        });
      }).toList(growable: false);

      final results = await Future.wait(futures);

      if (!mounted || thisReq != _requestId) return;

      for (final r in results) {
        _seriesByLabel[r.label] = r;
      }

      final startDt = timeline.nightStart.add(Duration(seconds: start.floor()));
      final endDt = timeline.nightStart.add(Duration(seconds: min(timeline.totalSeconds, end.ceil())));

      setState(() {
        _loadingSeries = false;
        _seriesInfo =
        'Plage: ${_fmtClock(startDt, withSeconds: span <= 120)} → ${_fmtClock(endDt, withSeconds: span <= 120)} • zoom=${span.toStringAsFixed(span < 60 ? 1 : 0)}s';
      });

      // prefetch (best effort, non bloquant)
      _prefetchAround(timeline, start, span, maxPoints);
    } catch (e) {
      if (!mounted || thisReq != _requestId) return;
      setState(() {
        _loadingSeries = false;
        _seriesInfo = 'Lecture impossible: $e';
      });
    }
  }

  void _prefetchAround(NightTimeline timeline, double start, double span, int maxPoints) {
    // Sans await: on ne bloque rien.
    final prevStart = max(0.0, start - span * 0.8);
    final nextStart = min(max(0.0, timeline.totalSeconds.toDouble() - span), start + span * 0.8);

    for (final label in _selectedLabels) {
      final kPrev = _cacheKey(label: label, start: prevStart, span: span, maxPoints: maxPoints);
      _cache.getOrLoad(kPrev, () {
        return NightSignalReader.readWindowF(
          timeline: timeline,
          globalStartSeconds: prevStart,
          windowSeconds: span,
          signalLabel: label,
          maxPoints: maxPoints,
        );
      });

      final kNext = _cacheKey(label: label, start: nextStart, span: span, maxPoints: maxPoints);
      _cache.getOrLoad(kNext, () {
        return NightSignalReader.readWindowF(
          timeline: timeline,
          globalStartSeconds: nextStart,
          windowSeconds: span,
          signalLabel: label,
          maxPoints: maxPoints,
        );
      });
    }
  }

  void _toggleLabel(String label) {
    setState(() {
      if (_selectedLabels.contains(label)) {
        if (_selectedLabels.length > 1) {
          _selectedLabels.remove(label);
        }
      } else {
        if (_selectedLabels.length < 6) {
          _selectedLabels.add(label);
        }
      }
    });
    _schedulePersist();
    _scheduleReload(immediate: true);
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

    final span = (_vp.end - _vp.start).abs();
    final withSeconds = span <= 120;

    final startDt = timeline.nightStart.add(Duration(seconds: _vp.start.floor()));
    final endDt = timeline.nightStart.add(Duration(seconds: min(timeline.totalSeconds, _vp.end.ceil())));

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
                  const SizedBox(height: 8),
                  Text(_seriesInfo ?? '—'),
                  if (_loadingSeries) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Zoom +',
                        onPressed: () {
                          _vp.spanSeconds = max(5.0, _vp.spanSeconds / 1.6);
                          _vp.clampTo(0, timeline.totalSeconds.toDouble());
                          _schedulePersist();
                          _scheduleReload();
                          setState(() {});
                        },
                        icon: const Icon(Icons.zoom_in),
                      ),
                      IconButton(
                        tooltip: 'Zoom -',
                        onPressed: () {
                          _vp.spanSeconds = min(timeline.totalSeconds.toDouble(), _vp.spanSeconds * 1.6);
                          _vp.clampTo(0, timeline.totalSeconds.toDouble());
                          _schedulePersist();
                          _scheduleReload();
                          setState(() {});
                        },
                        icon: const Icon(Icons.zoom_out),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_fmtClock(startDt, withSeconds: withSeconds)} → ${_fmtClock(endDt, withSeconds: withSeconds)}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_refHeader != null) ...[
            Text(
              'Signaux (2–6, même axe de temps)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _refHeader!.signals.map((s) {
                final label = s.label.trim();
                final unit = s.physicalDimension.trim();
                final selected = _selectedLabels.contains(label);
                final canSelectMore = selected || _selectedLabels.length < 6;
                return FilterChip(
                  label: Text(unit.isEmpty ? label : '$label ($unit)'),
                  selected: selected,
                  onSelected: canSelectMore
                      ? (_) => _toggleLabel(label)
                      : null,
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 12),
          ],

          // Zone gestuelle: pan (drag horizontal) + pinch zoom (2 doigts) + tap curseur
          LayoutBuilder(
            builder: (context, constraints) {
              _plotWidthPx = max(1.0, constraints.maxWidth);
              final xMin = _vp.start;
              final xMax = _vp.end;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  // curseur commun
                  final localX = d.localPosition.dx.clamp(0.0, _plotWidthPx);
                  final t = xMin + (localX / _plotWidthPx) * (xMax - xMin);
                  _vp.cursorSeconds = t.clamp(0.0, timeline.totalSeconds.toDouble());
                  _schedulePersist();
                  setState(() {});
                },
                onHorizontalDragUpdate: (d) {
                  final secondsPerPixel = (_vp.spanSeconds / _plotWidthPx);
                  _vp.centerSeconds -= d.delta.dx * secondsPerPixel;
                  _vp.clampTo(0, timeline.totalSeconds.toDouble());
                  _schedulePersist();
                  _scheduleReload();
                  setState(() {});
                },
                onScaleStart: (d) {
                  _scaleStartSpan = _vp.spanSeconds;
                  _scaleStartCenter = _vp.centerSeconds;
                  _scaleStartFocalX = d.focalPoint.dx;
                },
                onScaleUpdate: (d) {
                  if (d.pointerCount < 2) return;

                  // pan pendant pinch (approx via focalX)
                  final dx = d.focalPoint.dx - _scaleStartFocalX;
                  final secondsPerPixelAtStart = (_scaleStartSpan / _plotWidthPx);

                  final newSpan = (_scaleStartSpan / d.scale).clamp(5.0, timeline.totalSeconds.toDouble());
                  final newCenter = _scaleStartCenter - dx * secondsPerPixelAtStart;

                  _vp.spanSeconds = newSpan;
                  _vp.centerSeconds = newCenter;
                  _vp.clampTo(0, timeline.totalSeconds.toDouble());

                  _schedulePersist();
                  _scheduleReload();
                  setState(() {});
                },
                child: Column(
                  children: _selectedLabels.map((label) {
                    final r = _seriesByLabel[label];
                    final pts = r?.points ?? const <EdfDataPoint>[];
                    final unit = r?.unit;

                    if (pts.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Chargement: $label'),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SimpleLineChart(
                        title: label,
                        unit: unit,
                        points: pts,
                        height: 190,
                        xOrigin: timeline.nightStart,
                        xMin: xMin,
                        xMax: xMax,
                      ),
                    );
                  }).toList(growable: false),
                ),
              );
            },
          ),

          const SizedBox(height: 18),
          Text(
            'Gestes: glisser horizontal = pan, pincement = zoom, tap = curseur (persisté).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
