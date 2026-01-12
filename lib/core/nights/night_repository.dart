import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';

import '../imports/resmed_session_catalog.dart';
import '../imports/resmed_night_catalog.dart';
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

    // v0: on initialise sans drama. Si on doit migrer plus tard, ce bloc devient “v1->v2”.
    await db.metaSet(_kSchemaMetaKey, '$kDataSchemaVersion');
  }

  Future<bool> hasAnyNights() async {
    final row = await (db.selectOnly(db.nights)..addColumns([db.nights.nightKey])..limit(1)).getSingleOrNull();
    return row != null;
  }

  Future<void> ensureIndexBuilt() async {
    await ensureDataSchema();
    if (await hasAnyNights()) return;
    await rebuildIndexFromImports();
  }

  Future<void> rebuildIndexFromImports() async {
    final importsRoot = await AppPaths.importsRoot();
    final nights = await ResmedNightCatalog.scan(importsRoot);

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      await db.delete(db.sessions).go();
      await db.delete(db.nights).go();

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

        // Labels: on lit juste le header EDF du segment principal (pas de chargement complet).
        List<String> labels = const [];
        try {
          final refFile = n.primarySegment.bestFile;
          final header = await EdfHeaderParser.parseHeader(refFile);
          final set = header.signals.map((s) => s.label.trim()).where((s) => s.isNotEmpty).toSet();
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

  Future<List<NightListItem>> listNights({DateTime? from, DateTime? to, int? limit}) async {
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

    q.orderBy([(t) => OrderingTerm(expression: t.nightDateEpochDay, mode: OrderingMode.desc)]);

    if (limit != null && limit > 0) {
      q.limit(limit);
    }

    final rows = await q.get();

    return rows.map((r) {
      final labels = (r.labelsJson == null || r.labelsJson!.isEmpty)
          ? <String>[]
          : (jsonDecode(r.labelsJson!) as List).map((e) => e.toString()).toList();

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

    final nightRow = await (db.select(db.nights)..where((n) => n.nightKey.equals(nightKey))).getSingle();

    final sessionRows = await (db.select(db.sessions)..where((s) => s.nightKey.equals(nightKey))).get();
    sessionRows.sort((a, b) => a.startEpochMs.compareTo(b.startEpochMs));

    final segments = sessionRows.map((s) {
      final types = s.typesCsv.split(',').where((x) => x.trim().isNotEmpty).toList()..sort();
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
}
