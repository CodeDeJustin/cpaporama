import 'dart:io';

class ResmedEdfPick {
  ResmedEdfPick({
    required this.file,
    required this.reason,
    required this.sessionsDetected,
    this.sessionStart,
    this.sessionKey,
    this.availableTypes = const [],
  });

  final File file;
  final String reason;

  /// Combien de sessions ResMed (YYYYMMDD_HHMMSS) on a pu identifier.
  final int sessionsDetected;

  /// Info utile si on a reconnu le pattern ResMed.
  final DateTime? sessionStart;
  final String? sessionKey;
  final List<String> availableTypes;
}

class _Entry {
  _Entry(this.file, this.start, this.type, this.sessionKey);

  final File file;
  final DateTime start;
  final String type; // ex: PLD, BRP, EVE...
  final String sessionKey; // ex: 20251222_231500
}

class ResmedDatalogPicker {
  // Exemple: 20130101_120003_PLD.edf
  static final RegExp _rx = RegExp(r'^(\d{8})_(\d{6})_([A-Za-z]{3})\.edf$');

  static String _baseName(File f) {
    final segs = f.uri.pathSegments;
    return segs.isNotEmpty ? segs.last : f.path.split(Platform.pathSeparator).last;
  }

  static DateTime? _parseStart(String yyyymmdd, String hhmmss) {
    if (yyyymmdd.length != 8 || hhmmss.length != 6) return null;
    final y = int.tryParse(yyyymmdd.substring(0, 4));
    final m = int.tryParse(yyyymmdd.substring(4, 6));
    final d = int.tryParse(yyyymmdd.substring(6, 8));
    final hh = int.tryParse(hhmmss.substring(0, 2));
    final mm = int.tryParse(hhmmss.substring(2, 4));
    final ss = int.tryParse(hhmmss.substring(4, 6));
    if ([y, m, d, hh, mm, ss].any((v) => v == null)) return null;
    return DateTime(y!, m!, d!, hh!, mm!, ss!);
  }

  static const List<String> _typePriority = <String>[
    'PLD', // souvent le plus “waveform utile”
    'BRP',
    'SAD',
    'CSL',
    'EVE',
    'STR',
  ];

  static Future<ResmedEdfPick> pickBestEdf(List<File> edfFiles) async {
    if (edfFiles.isEmpty) {
      throw ArgumentError('Liste EDF vide.');
    }

    // 1) Index des fichiers qui matchent le pattern ResMed DATALOG.
    final entries = <_Entry>[];

    for (final f in edfFiles) {
      final name = _baseName(f);
      final m = _rx.firstMatch(name);
      if (m == null) continue;

      final date = m.group(1)!;
      final time = m.group(2)!;
      final type = m.group(3)!.toUpperCase();

      final start = _parseStart(date, time);
      if (start == null) continue;

      final sessionKey = '${date}_$time';
      entries.add(_Entry(f, start, type, sessionKey));
    }

    if (entries.isNotEmpty) {
      // 2) Grouper par session et choisir la plus récente.
      final bySession = <String, List<_Entry>>{};
      for (final e in entries) {
        bySession.putIfAbsent(e.sessionKey, () => []).add(e);
      }

      String newestKey = bySession.keys.first;
      DateTime newestStart = bySession[newestKey]!.first.start;

      for (final key in bySession.keys) {
        final s = bySession[key]!.first.start;
        if (s.isAfter(newestStart)) {
          newestStart = s;
          newestKey = key;
        }
      }

      final newestEntries = bySession[newestKey]!;
      final types = newestEntries.map((e) => e.type).toSet().toList()..sort();

      // 3) Choisir le meilleur type selon priorité.
      _Entry chosen = newestEntries.first;
      for (final wanted in _typePriority) {
        final hit = newestEntries.where((e) => e.type == wanted).toList();
        if (hit.isNotEmpty) {
          chosen = hit.first;
          break;
        }
      }

      return ResmedEdfPick(
        file: chosen.file,
        reason:
        'ResMed DATALOG détecté: session la plus récente $newestKey, types=${types.join(", ")} → choisi ${chosen.type}',
        sessionsDetected: bySession.length,
        sessionStart: newestStart,
        sessionKey: newestKey,
        availableTypes: types,
      );
    }

    // 4) Fallback non-ResMed: garder le comportement actuel (premier EDF).
    return ResmedEdfPick(
      file: edfFiles.first,
      reason: 'Pattern ResMed DATALOG non détecté → fallback: premier EDF',
      sessionsDetected: 0,
    );
  }
}
