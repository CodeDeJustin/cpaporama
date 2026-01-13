import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';

import '../imports/resmed_night_catalog.dart';
import '../imports/resmed_session_catalog.dart';
import '../parser/edf_header_parser.dart';
import '../storage/app_database.dart';
import '../storage/app_paths.dart';

class NightListItem {
  NightListItem({
    required this.nightKey,
    required this.nightDate,
    required this.start,
    required this.end,
    required this.sessionsCount,
    required this.gapCount,
    required this.gapSeconds,
    required this.useSeconds,
    required this.labels,
  });

  final String nightKey;
  final DateTime nightDate;
  final DateTime start;
  final DateTime end;
  final int sessionsCount;
  final int gapCount;
  final int gapSeconds;
  final int useSeconds;
  final List<String> labels;
}

class NightRepository {
  NightRepository(this.db);

  final AppDatabase db;

  static const int kDataSchemaVersion = 1;
  static const String _kSchemaMetaKey = 'dataSchemaVersion';

  int _epochDay(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  DateTime _nightDateFromKey(String key) {
    final y = int.parse(key.substring(0, 4));
    final m = int.parse(key.substring(4, 6));
    final d = int.parse(key.substring(6, 8));
    return DateTime(y, m, d);
  }

  Future<void> ensureDataSchema() async {
    final vStr = await db.metaGet(_kSchemaMetaKey);
    final v = int.tryParse(vStr ?? '');
    if (v == kDataSchemaVersion) return;

    // v0: on initialise. Si on doit migrer plus tard, ce bloc devient “v1->v2”.
    await db.metaSet(_kSchemaMetaKey, '$kDataSchemaVersion');
  }

  Future<bool> hasAnyNights() async {
    final row = await (db.selectOnly(db.nights)
      ..addColumns([db.nights.nightKey])
      ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> ensureIndexBuilt() async {
    await ensureDataSchema();
    if (await hasAnyNights()) return;
    await rebuildIndexFromImports();
  }

  Future<void> rebuildIndexFromImports() async {
    await ensureDataSchema();

    final importsRoot = await AppPaths.importsRoot();
    final nights = await ResmedNightCatalog.scan(importsRoot);
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Pré-calc hors transaction (évite de bloquer la DB pendant des I/O fichiers).
    final writes = <_NightWrite>[];
    for (final n in nights) {
      final segs = [...n.segments]..sort((a, b) => a.start.compareTo(b.start));

      int gapCount = 0;
      int gapSeconds = 0;
      int useSeconds = 0;

      for (int i = 0; i < segs.length; i++) {
        useSeconds += max(0, segs[i].totalSeconds ?? 0);
        if (i == 0) continue;

        final prev = segs[i - 1];
        final next = segs[i];

        final prevDur = prev.totalSeconds ?? 0;
        final prevEnd = prev.start.add(Duration(seconds: max(0, prevDur)));

        if (next.start.isAfter(prevEnd)) {
          gapCount++;
          gapSeconds += next.start.difference(prevEnd).inSeconds;
        }
      }

      // Labels: header EDF du segment principal seulement (pas de chargement complet).
      List<String> labels = const [];
      try {
        final refFile = n.primarySegment.bestFile;
        final header = await EdfHeaderParser.parseHeader(refFile);
        final set = header.signals
            .map((s) => s.label.trim())
            .where((s) => s.isNotEmpty)
            .toSet();
        labels = set.toList()..sort();
      } catch (_) {
        labels = const [];
      }

      final nightRow = NightsCompanion.insert(
        nightKey: n.nightKey,
        nightDateEpochDay: _epochDay(n.nightDate),
        startEpochMs: n.start.millisecondsSinceEpoch,
        endEpochMs: n.end.millisecondsSinceEpoch,
        sessionsCount: segs.length,
        gapCount: Value(gapCount),
        gapSeconds: Value(gapSeconds),
        useSeconds: Value(useSeconds),
        labelsJson: Value(jsonEncode(labels)),
        updatedAtEpochMs: nowMs,
      );

      final sessionRows = segs
          .map(
            (s) => SessionsCompanion.insert(
          sessionKey: s.sessionKey,
          nightKey: n.nightKey,
          startEpochMs: s.start.millisecondsSinceEpoch,
          durationSeconds: Value(s.totalSeconds),
          bestType: s.bestType,
          bestFilePath: s.bestFile.path,
          typesCsv: s.types.join(','),
        ),
      )
          .toList(growable: false);

      writes.add(_NightWrite(nightRow, sessionRows));
    }

    await db.transaction(() async {
      await db.delete(db.sessions).go();
      await db.delete(db.nights).go();

      for (final w in writes) {
        await db.into(db.nights).insertOnConflictUpdate(w.night);
        for (final s in w.sessions) {
          await db.into(db.sessions).insertOnConflictUpdate(s);
        }
      }
    });
  }

  Future<List<NightListItem>> listNights({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    await ensureIndexBuilt();

    final q = db.select(db.nights);

    if (from != null && to != null) {
      final a = _epochDay(from);
      final b = _epochDay(to);
      final lo = min(a, b);
      final hi = max(a, b);
      q.where((t) => t.nightDateEpochDay.isBetweenValues(lo, hi));
    } else if (from != null) {
      q.where((t) => t.nightDateEpochDay.isBiggerOrEqualValue(_epochDay(from)));
    } else if (to != null) {
      q.where((t) => t.nightDateEpochDay.isSmallerOrEqualValue(_epochDay(to)));
    }

    q.orderBy([
          (t) => OrderingTerm(
        expression: t.nightDateEpochDay,
        mode: OrderingMode.desc,
      )
    ]);

    if (limit != null && limit > 0) {
      q.limit(limit);
    }

    final rows = await q.get();

    return rows.map((r) {
      final labels = (r.labelsJson == null || r.labelsJson!.isEmpty)
          ? <String>[]
          : (jsonDecode(r.labelsJson!) as List)
          .map((e) => e.toString())
          .toList();

      return NightListItem(
        nightKey: r.nightKey,
        nightDate: _nightDateFromKey(r.nightKey),
        start: DateTime.fromMillisecondsSinceEpoch(r.startEpochMs),
        end: DateTime.fromMillisecondsSinceEpoch(r.endEpochMs),
        sessionsCount: r.sessionsCount,
        gapCount: r.gapCount,
        gapSeconds: r.gapSeconds,
        useSeconds: r.useSeconds,
        labels: labels,
      );
    }).toList(growable: false);
  }

  Future<ResmedNightSummary> getNight(String nightKey) async {
    await ensureIndexBuilt();

    final nightRow = await (db.select(db.nights)
      ..where((n) => n.nightKey.equals(nightKey)))
        .getSingle();

    final sessionRows = await (db.select(db.sessions)
      ..where((s) => s.nightKey.equals(nightKey)))
        .get();
    sessionRows.sort((a, b) => a.startEpochMs.compareTo(b.startEpochMs));

    final segments = sessionRows.map((s) {
      final types = s.typesCsv
          .split(',')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toList()
        ..sort();

      return ResmedSessionSummary(
        sessionKey: s.sessionKey,
        start: DateTime.fromMillisecondsSinceEpoch(s.startEpochMs),
        types: types,
        bestFile: File(s.bestFilePath),
        bestType: s.bestType,
        totalSeconds: s.durationSeconds,
      );
    }).toList(growable: false);

    return ResmedNightSummary(
      nightKey: nightRow.nightKey,
      nightDate: _nightDateFromKey(nightRow.nightKey),
      segments: segments,
    );
  }

  /// ✅ v0.2.9: upsert ciblé après syncLatest/syncLastN/syncRange
  /// - supprime/reconstruit uniquement les nuits touchées (et leurs sessions)
  /// - si une nuit n’existe plus côté fichiers, on la retire de la DB
  Future<void> upsertIndexForNightKeys(Iterable<String> nightKeys) async {
    await ensureDataSchema();

    final keys = nightKeys
        .map((e) => e.toString())
        .where((k) => RegExp(r'^\d{8}$').hasMatch(k))
        .toSet();
    if (keys.isEmpty) return;

    final nights = await _scanResmedNightsForKeys(keys);
    final byKey = <String, ResmedNightSummary>{
      for (final n in nights) n.nightKey: n,
    };

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      for (final nightKey in keys) {
        // Nettoyage ciblé (sessions de cette nuit uniquement)
        await (db.delete(db.sessions)..where((s) => s.nightKey.equals(nightKey)))
            .go();

        final n = byKey[nightKey];
        if (n == null) {
          // La nuit n’existe plus côté fichiers -> on la retire.
          await (db.delete(db.nights)..where((t) => t.nightKey.equals(nightKey)))
              .go();
          continue;
        }

        final segs = [...n.segments]..sort((a, b) => a.start.compareTo(b.start));

        int gapCount = 0;
        int gapSeconds = 0;
        int useSeconds = 0;

        for (int i = 0; i < segs.length; i++) {
          useSeconds += max(0, segs[i].totalSeconds ?? 0);
          if (i == 0) continue;

          final prev = segs[i - 1];
          final next = segs[i];

          final prevDur = prev.totalSeconds ?? 0;
          final prevEnd = prev.start.add(Duration(seconds: max(0, prevDur)));

          if (next.start.isAfter(prevEnd)) {
            gapCount++;
            gapSeconds += next.start.difference(prevEnd).inSeconds;
          }
        }

        // Labels: header EDF du segment principal seulement
        List<String> labels = const [];
        try {
          final refFile = n.primarySegment.bestFile;
          final header = await EdfHeaderParser.parseHeader(refFile);
          final set = header.signals
              .map((s) => s.label.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          labels = set.toList()..sort();
        } catch (_) {
          labels = const [];
        }

        await db.into(db.nights).insertOnConflictUpdate(
          NightsCompanion.insert(
            nightKey: n.nightKey,
            nightDateEpochDay: _epochDay(n.nightDate),
            startEpochMs: n.start.millisecondsSinceEpoch,
            endEpochMs: n.end.millisecondsSinceEpoch,
            sessionsCount: segs.length,
            gapCount: Value(gapCount),
            gapSeconds: Value(gapSeconds),
            useSeconds: Value(useSeconds),
            labelsJson: Value(jsonEncode(labels)),
            updatedAtEpochMs: nowMs,
          ),
        );

        for (final s in segs) {
          await db.into(db.sessions).insertOnConflictUpdate(
            SessionsCompanion.insert(
              sessionKey: s.sessionKey,
              nightKey: n.nightKey,
              startEpochMs: s.start.millisecondsSinceEpoch,
              durationSeconds: Value(s.totalSeconds),
              bestType: s.bestType,
              bestFilePath: s.bestFile.path,
              typesCsv: s.types.join(','),
            ),
          );
        }
      }
    });
  }

  Future<List<ResmedNightSummary>> _scanResmedNightsForKeys(
      Set<String> nightKeys,
      ) async {
    final importsRoot = await AppPaths.importsRoot();
    final resmedRoot = Directory(
      '${importsRoot.path}${Platform.pathSeparator}resmed',
    );
    if (!await resmedRoot.exists()) return [];

    // On ne scanne QUE les dossiers sessionKey qui tombent dans nightKeys.
    final sessionDirs = <Directory>[];
    await for (final ent in resmedRoot.list(followLinks: false)) {
      if (ent is! Directory) continue;
      final name = ent.path.split(Platform.pathSeparator).last;

      final m = RegExp(r'^(\d{8})_(\d{6})$').firstMatch(name);
      if (m == null) continue;

      final yyyymmdd = m.group(1)!;
      final hhmmss = m.group(2)!;

      final y = int.parse(yyyymmdd.substring(0, 4));
      final mo = int.parse(yyyymmdd.substring(4, 6));
      final d = int.parse(yyyymmdd.substring(6, 8));
      final hh = int.parse(hhmmss.substring(0, 2));
      final mm = int.parse(hhmmss.substring(2, 4));
      final ss = int.parse(hhmmss.substring(4, 6));

      final start = DateTime(y, mo, d, hh, mm, ss);
      final nk = ResmedNightCatalog.nightKeyFromStart(start);

      if (nightKeys.contains(nk)) sessionDirs.add(ent);
    }

    if (sessionDirs.isEmpty) return [];

    // Chaque sessionDir contient typiquement une seule sessionKey, donc scan local et rapide.
    final sessions = <ResmedSessionSummary>[];
    for (final dir in sessionDirs) {
      final list = await ResmedSessionCatalog.scan(dir);
      sessions.addAll(list);
    }

    // Filtre “thérapie”
    const therapyTypes = {'PLD', 'BRP', 'SA2', 'SAD'};
    final therapySessions =
    sessions.where((s) => therapyTypes.contains(s.bestType)).toList();
    if (therapySessions.isEmpty) return [];

    final byNight = <String, List<ResmedSessionSummary>>{};
    for (final s in therapySessions) {
      final nk = ResmedNightCatalog.nightKeyFromStart(s.start);
      if (!nightKeys.contains(nk)) continue;
      byNight.putIfAbsent(nk, () => []).add(s);
    }

    final out = <ResmedNightSummary>[];
    for (final kv in byNight.entries) {
      final nk = kv.key;
      final segs = kv.value..sort((a, b) => a.start.compareTo(b.start));
      out.add(
        ResmedNightSummary(
          nightKey: nk,
          nightDate: _nightDateFromKey(nk),
          segments: segs,
        ),
      );
    }

    out.sort((a, b) => b.nightDate.compareTo(a.nightDate));
    return out;
  }

  // --- Diagnostics (dev-only) ---

  Future<void> clearAll() async {
    await ensureDataSchema();
    await db.transaction(() async {
      await db.delete(db.sessions).go();
      await db.delete(db.nights).go();
    });
  }

  Future<int> countNights() async {
    final exp = db.nights.nightKey.count();
    final row = await (db.selectOnly(db.nights)..addColumns([exp])).getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> countSessions() async {
    final exp = db.sessions.sessionKey.count();
    final row =
    await (db.selectOnly(db.sessions)..addColumns([exp])).getSingle();
    return row.read(exp) ?? 0;
  }
}

class _NightWrite {
  _NightWrite(this.night, this.sessions);
  final NightsCompanion night;
  final List<SessionsCompanion> sessions;
}
