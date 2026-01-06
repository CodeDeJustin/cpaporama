import 'dart:io';

import 'resmed_session_catalog.dart';

class ResmedNightSummary {
  ResmedNightSummary({
    required this.nightKey, // YYYYMMDD (frontière midi)
    required this.nightDate, // Date (local)
    required this.segments, // sessions de cette nuit
  });

  final String nightKey;
  final DateTime nightDate;
  final List<ResmedSessionSummary> segments;

  DateTime get start =>
      segments.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);

  DateTime get end {
    DateTime best = start;
    for (final s in segments) {
      final e = s.end ?? s.start; // end si dispo, sinon fallback start
      if (e.isAfter(best)) best = e;
    }
    return best;
  }

  int get segmentsCount => segments.length;

  ResmedSessionSummary get primarySegment {
    const priority = <String>['PLD', 'BRP', 'SA2', 'SAD', 'CSL', 'EVE', 'STR'];

    for (final wanted in priority) {
      final hits = segments.where((s) => s.bestType == wanted).toList();
      if (hits.isNotEmpty) {
        hits.sort((a, b) => b.bestFile.lengthSync().compareTo(a.bestFile.lengthSync()));
        return hits.first;
      }
    }

    final sorted = [...segments]
      ..sort((a, b) => b.bestFile.lengthSync().compareTo(a.bestFile.lengthSync()));
    return sorted.first;
  }
}

class ResmedNightCatalog {
  static String _pad2(int v) => v.toString().padLeft(2, '0');
  static String _pad4(int v) => v.toString().padLeft(4, '0');

  /// OSCAR-like: tout ce qui est avant midi appartient à la "nuit" de la veille.
  static String nightKeyFromStart(DateTime start) {
    var d = start;
    if (d.hour < 12) d = d.subtract(const Duration(days: 1));
    return '${_pad4(d.year)}${_pad2(d.month)}${_pad2(d.day)}';
  }

  static DateTime _nightDateFromKey(String key) {
    final y = int.parse(key.substring(0, 4));
    final m = int.parse(key.substring(4, 6));
    final d = int.parse(key.substring(6, 8));
    return DateTime(y, m, d);
  }

  static Future<List<ResmedNightSummary>> scan(Directory importsRoot) async {
    if (!await importsRoot.exists()) return [];

    final sessions = await ResmedSessionCatalog.scan(importsRoot);
    if (sessions.isEmpty) return [];

// On garde seulement les sessions "thérapie" (celles qui ont des signaux continus).
    const therapyTypes = {'PLD', 'BRP', 'SA2', 'SAD'};

    final therapySessions = sessions
        .where((s) => therapyTypes.contains(s.bestType))
        .toList();

    if (therapySessions.isEmpty) return [];

    final byNight = <String, List<ResmedSessionSummary>>{};
    for (final s in therapySessions) {
      final nk = nightKeyFromStart(s.start);
      byNight.putIfAbsent(nk, () => []).add(s);
    }

    final nights = <ResmedNightSummary>[];
    for (final kv in byNight.entries) {
      final nk = kv.key;
      final segs = kv.value..sort((a, b) => a.start.compareTo(b.start));
      nights.add(
        ResmedNightSummary(
          nightKey: nk,
          nightDate: _nightDateFromKey(nk),
          segments: segs,
        ),
      );
    }

    nights.sort((a, b) => b.nightDate.compareTo(a.nightDate));
    return nights;
  }
}

