import 'dart:io';

class ResmedSessionSummary {
  ResmedSessionSummary({
    required this.sessionKey,
    required this.start,
    required this.types,
    required this.bestFile,
    required this.bestType,
  });

  final String sessionKey; // YYYYMMDD_HHMMSS
  final DateTime start;
  final List<String> types; // ex: [BRP, PLD, SA2]
  final File bestFile;
  final String bestType;
}

class _Entry {
  _Entry({
    required this.file,
    required this.start,
    required this.type,
    required this.sessionKey,
  });

  final File file;
  final DateTime start;
  final String type;
  final String sessionKey;
}

class ResmedSessionCatalog {
  // Exemple: 20251222_035217_PLD.edf / 20251222_035217_SA2.edf
  static final RegExp _rx =
  RegExp(r'^(\d{8})_(\d{6})_([A-Za-z0-9]{3})\.edf$');

  static const List<String> _typePriority = <String>[
    'PLD',
    'BRP',
    'SA2',
    'SAD',
    'CSL',
    'EVE',
    'STR',
  ];

  static String _baseName(String path) =>
      path.split(Platform.pathSeparator).last;

  static DateTime? _parseStart(String yyyymmdd, String hhmmss) {
    final y = int.tryParse(yyyymmdd.substring(0, 4));
    final m = int.tryParse(yyyymmdd.substring(4, 6));
    final d = int.tryParse(yyyymmdd.substring(6, 8));
    final hh = int.tryParse(hhmmss.substring(0, 2));
    final mm = int.tryParse(hhmmss.substring(2, 4));
    final ss = int.tryParse(hhmmss.substring(4, 6));
    if ([y, m, d, hh, mm, ss].any((v) => v == null)) return null;
    return DateTime(y!, m!, d!, hh!, mm!, ss!);
  }

  static Future<List<ResmedSessionSummary>> scan(Directory root) async {
    if (!await root.exists()) return [];

    final entries = <_Entry>[];

    await for (final ent in root.list(recursive: true, followLinks: false)) {
      if (ent is! File) continue;
      if (!ent.path.toLowerCase().endsWith('.edf')) continue;

      final name = _baseName(ent.path);
      final m = _rx.firstMatch(name);
      if (m == null) continue;

      final date = m.group(1)!;
      final time = m.group(2)!;
      final type = m.group(3)!.toUpperCase();

      final start = _parseStart(date, time);
      if (start == null) continue;

      final sessionKey = '${date}_$time';
      entries.add(_Entry(file: ent, start: start, type: type, sessionKey: sessionKey));
    }

    if (entries.isEmpty) return [];

    // group by session
    final bySession = <String, List<_Entry>>{};
    for (final e in entries) {
      bySession.putIfAbsent(e.sessionKey, () => []).add(e);
    }

    final summaries = <ResmedSessionSummary>[];

    for (final kv in bySession.entries) {
      final sessionKey = kv.key;
      final list = kv.value;

      // start: toutes les entrées d'une session ont la même start
      final start = list.first.start;

      final typesSet = list.map((e) => e.type).toSet();
      final types = typesSet.toList()..sort();

      // best file by priority
      _Entry chosen = list.first;
      String chosenType = chosen.type;

      for (final wanted in _typePriority) {
        final hit = list.where((e) => e.type == wanted).toList();
        if (hit.isNotEmpty) {
          chosen = hit.first;
          chosenType = wanted;
          break;
        }
      }

      summaries.add(
        ResmedSessionSummary(
          sessionKey: sessionKey,
          start: start,
          types: types,
          bestFile: chosen.file,
          bestType: chosenType,
        ),
      );
    }

    // most recent first
    summaries.sort((a, b) => b.start.compareTo(a.start));
    return summaries;
  }
}
