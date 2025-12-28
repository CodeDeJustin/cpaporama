import 'dart:io';

class ResmedSessionFile {
  ResmedSessionFile({required this.file, required this.type});

  final File file;
  final String type; // PLD, BRP, SA2, EVE, ...
}

class ResmedEdfPick {
  ResmedEdfPick({
    required this.file,
    required this.reason,
    required this.sessionsDetected,
    this.sessionStart,
    this.sessionKey,
    this.availableTypes = const [],
    this.sessionFiles = const [],
  });

  final File file;
  final String reason;
  final int sessionsDetected;

  final DateTime? sessionStart;
  final String? sessionKey;
  final List<String> availableTypes;

  final List<ResmedSessionFile> sessionFiles; // <-- nouveau
}

class _Entry {
  _Entry(this.file, this.start, this.type, this.sessionKey);
  final File file;
  final DateTime start;
  final String type;       // PLD, BRP, SA2, EVE, CSL, ...
  final String sessionKey; // YYYYMMDD_HHMMSS
}

class ResmedSdScanner {
  // Exemple: 20251221_230125_PLD.edf  (type = 3 chars alphanum, ex SA2)
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

  /// `pickedDirPath` peut être:
  /// - la racine SD (contient DATALOG/)
  /// - le dossier DATALOG lui-même
  static Future<ResmedEdfPick> scanAndPickBest(String pickedDirPath) async {
    final pickedDir = Directory(pickedDirPath);
    if (!await pickedDir.exists()) {
      throw Exception('Dossier introuvable: $pickedDirPath');
    }

    // Trouver DATALOG
    Directory datalogDir;
    final datalogCandidate =
    Directory('${pickedDir.path}${Platform.pathSeparator}DATALOG');

    if (await datalogCandidate.exists()) {
      datalogDir = datalogCandidate;
    } else if (_baseName(pickedDir.path).toUpperCase() == 'DATALOG') {
      datalogDir = pickedDir;
    } else {
      throw Exception('Structure ResMed non détectée: DATALOG manquant.');
    }

    // Scanner toutes les sous-dossiers date (YYYYMMDD) dans DATALOG
    final entries = <_Entry>[];

    final children = datalogDir.listSync(followLinks: false);
    final dateDirs = children.whereType<Directory>().where((d) {
      final name = _baseName(d.path);
      return RegExp(r'^\d{8}$').hasMatch(name);
    }).toList();

    for (final d in dateDirs) {
      // pas récursif: on reste dans le dossier date
      final items = d.listSync(followLinks: false);
      for (final it in items) {
        if (it is! File) continue;
        if (!it.path.toLowerCase().endsWith('.edf')) continue;

        final name = _baseName(it.path);
        final m = _rx.firstMatch(name);
        if (m == null) continue;

        final date = m.group(1)!;
        final time = m.group(2)!;
        final type = m.group(3)!.toUpperCase();

        final start = _parseStart(date, time);
        if (start == null) continue;

        final sessionKey = '${date}_$time';
        entries.add(_Entry(it, start, type, sessionKey));
      }
    }

    if (entries.isEmpty) {
      throw Exception('Aucun EDF ResMed (pattern DATALOG) trouvé dans: ${datalogDir.path}');
    }

    // Grouper par session et choisir la plus récente
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

    final sessionFiles = newestEntries
        .map((e) => ResmedSessionFile(file: e.file, type: e.type))
        .toList();

    // Choisir le meilleur type selon priorité
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
      'ResMed DATALOG: ${bySession.length} session(s), plus récente=$newestKey, types=${types.join(", ")} → choisi ${chosen.type}',
      sessionsDetected: bySession.length,
      sessionStart: newestStart,
      sessionFiles: sessionFiles,
      sessionKey: newestKey,
      availableTypes: types,
    );
  }
}
