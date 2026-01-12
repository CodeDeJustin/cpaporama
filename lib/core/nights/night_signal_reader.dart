import 'dart:io';
import 'dart:math';

import '../parser/edf_header_parser.dart';
import '../parser/edf_signal_reader.dart';
import 'night_timeline.dart';

class NightWindowReadResult {
  NightWindowReadResult({
    required this.label,
    required this.unit,
    required this.points,
  });

  final String label;
  final String unit;

  /// Points dont tSeconds = secondes GLOBAL (depuis timeline.nightStart).
  /// Les gaps sont marqués par value = double.nan (le chart split en chunks).
  final List<EdfDataPoint> points;
}

class NightSignalReader {
  static final Map<String, EdxEdfHeader> _headerCache = {};

  static Future<EdxEdfHeader> _headerFor(File f) async {
    final key = f.path;
    final cached = _headerCache[key];
    if (cached != null) return cached;
    final h = await EdfHeaderParser.parseHeader(f);
    _headerCache[key] = h;
    return h;
  }

  static int? _findIndexByLabel(EdxEdfHeader header, String label) {
    final wanted = label.trim().toLowerCase();
    for (var i = 0; i < header.numSignals; i++) {
      if (header.signals[i].label.trim().toLowerCase() == wanted) return i;
    }
    return null;
  }

  /// Back-compat (int) -> route vers la version float.
  static Future<NightWindowReadResult> readWindow({
    required NightTimeline timeline,
    required int globalStartSeconds,
    required int windowSeconds,
    required String signalLabel,
    int maxPoints = 3000,
  }) {
    return readWindowF(
      timeline: timeline,
      globalStartSeconds: globalStartSeconds.toDouble(),
      windowSeconds: windowSeconds.toDouble(),
      signalLabel: signalLabel,
      maxPoints: maxPoints,
    );
  }

  /// Version float: start/span continus (pan/zoom sans “clic”)
  static Future<NightWindowReadResult> readWindowF({
    required NightTimeline timeline,
    required double globalStartSeconds,
    required double windowSeconds,
    required String signalLabel,
    int maxPoints = 3000,
  }) async {
    final globalEnd = globalStartSeconds + windowSeconds;
    final out = <EdfDataPoint>[];

    String unit = '';
    double? lastCovered; // secondes globales

    void addGap(double a, double b) {
      if (b <= a) return;
      out.add(EdfDataPoint(a, double.nan));
      out.add(EdfDataPoint(b, double.nan));
    }

    // segments qui intersectent [globalStart, globalEnd]
    final segs = timeline.segments.where((s) {
      final s0 = s.offsetSeconds.toDouble();
      final s1 = s.endOffsetSeconds.toDouble();
      return s1 > globalStartSeconds && s0 < globalEnd;
    }).toList()
      ..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));

    for (final seg in segs) {
      final segStart = seg.offsetSeconds.toDouble();
      final segEnd = seg.endOffsetSeconds.toDouble();

      final localStart = max(0.0, globalStartSeconds - segStart);
      final localEnd = min(seg.durationSeconds.toDouble(), globalEnd - segStart);
      final localWindow = max(0.0, localEnd - localStart);

      if (localWindow <= 0) continue;

      // gap avant ce segment
      if (lastCovered == null) {
        if (segStart > globalStartSeconds) {
          addGap(globalStartSeconds, min(segStart, globalEnd));
        }
      } else {
        final gapA = max(lastCovered!, globalStartSeconds);
        final gapB = min(segStart, globalEnd);
        if (gapB > gapA) addGap(gapA, gapB);
      }

      final file = seg.session.bestFile;

      final header = await _headerFor(file);
      final idx = _findIndexByLabel(header, signalLabel);

      if (idx == null) {
        // signal absent => gap sur portion couverte par ce segment
        final a = segStart + localStart;
        final b = segStart + localEnd;
        addGap(max(a, globalStartSeconds), min(b, globalEnd));
        lastCovered = max(lastCovered ?? 0.0, min(segStart + localEnd, globalEnd));
        continue;
      }

      if (unit.isEmpty) {
        unit = header.signals[idx].physicalDimension.trim();
      }

      final remaining = max(100, maxPoints - out.length);
      if (remaining <= 0) break;

      final series = await EdfSignalReader.readSignalSeriesF(
        file: file,
        header: header,
        signalIndex: idx,
        startTimeSeconds: localStart,
        windowSeconds: localWindow,
        maxPoints: remaining,
      );

      final baseGlobal = segStart + localStart;
      for (final p in series.points) {
        out.add(EdfDataPoint(baseGlobal + p.tSeconds, p.value));
      }

      lastCovered = max(lastCovered ?? 0.0, min(segStart + localEnd, globalEnd));
      if ((maxPoints - out.length) <= 0) break;
    }

    // gap final
    if (lastCovered != null && lastCovered! < globalEnd) {
      addGap(max(lastCovered!, globalStartSeconds), globalEnd);
    }

    if (out.length > maxPoints) {
      out.removeRange(maxPoints, out.length);
    }

    return NightWindowReadResult(
      label: signalLabel,
      unit: unit,
      points: out,
    );
  }
}
