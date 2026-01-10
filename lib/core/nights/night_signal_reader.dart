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

  static Future<NightWindowReadResult> readWindow({
    required NightTimeline timeline,
    required int globalStartSeconds,
    required int windowSeconds,
    required String signalLabel,
    int maxPoints = 3000,
  }) async {
    final globalEnd = globalStartSeconds + windowSeconds;
    final out = <EdfDataPoint>[];

    String unit = '';
    int? lastCovered; // en secondes globales

    void addGap(int a, int b) {
      if (b <= a) return;
      // Deux NaN suffisent: le chart coupe la ligne (et on évite toute diagonale)
      out.add(EdfDataPoint(a.toDouble(), double.nan));
      out.add(EdfDataPoint(b.toDouble(), double.nan));
    }

    // segments qui intersectent [globalStart, globalEnd]
    final segs = timeline.segments.where((s) {
      final s0 = s.offsetSeconds;
      final s1 = s.endOffsetSeconds;
      return s1 > globalStartSeconds && s0 < globalEnd;
    }).toList()
      ..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds));

    for (final seg in segs) {
      final segStart = seg.offsetSeconds;
      final segEnd = seg.endOffsetSeconds;

      final localStart = max(0, globalStartSeconds - segStart);
      final localEnd = min(seg.durationSeconds, globalEnd - segStart);
      final localWindow = max(0, localEnd - localStart);

      if (localWindow <= 0) continue;

      // Gap entre couverture précédente et ce segment (dans la fenêtre)
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
        // signal absent => gap sur la portion de fenêtre couverte par ce segment
        final a = segStart + localStart;
        final b = segStart + localEnd;
        addGap(max(a, globalStartSeconds), min(b, globalEnd));
        lastCovered = max(lastCovered ?? 0, min(segStart + localEnd, globalEnd));
        continue;
      }

      if (unit.isEmpty) {
        unit = header.signals[idx].physicalDimension.trim();
      }

      // Budget points: éviter d’exploser si plusieurs segments
      final remaining = max(100, maxPoints - out.length);
      if (remaining <= 0) break;

      final series = await EdfSignalReader.readSignalSeries(
        file: file,
        header: header,
        signalIndex: idx,
        startSeconds: localStart,
        windowSeconds: localWindow,
        maxPoints: remaining,
      );

      final baseGlobal = (segStart + localStart).toDouble();
      for (final p in series.points) {
        out.add(EdfDataPoint(baseGlobal + p.tSeconds, p.value));
      }

      lastCovered = max(lastCovered ?? 0, min(segStart + localEnd, globalEnd));
      if ((maxPoints - out.length) <= 0) break;
    }

    // Gap final si on finit avant globalEnd
    if (lastCovered != null && lastCovered! < globalEnd) {
      addGap(max(lastCovered!, globalStartSeconds), globalEnd);
    }

    // Nettoyage si on a trop de points
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
