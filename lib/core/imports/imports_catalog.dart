import 'dart:io';
import 'dart:math';

import '../parser/edf_header_parser.dart';

class ImportedEdfSummary {
  ImportedEdfSummary({
    required this.file,
    required this.fileName,
    required this.numSignals,
    required this.totalSeconds,
    required this.start,
  });

  final File file;
  final String fileName;
  final int numSignals;
  final int totalSeconds;
  final DateTime? start;
}

class ImportsCatalog {
  static Future<Directory> _importsDir() async {
    // ImportScreen utilise getApplicationDocumentsDirectory() + /imports
    // On ne le refait pas ici pour éviter dépendance path_provider dans core.
    // Donc on reçoit le dossier depuis l’appelant.
    throw UnimplementedError();
  }

  static DateTime? parseEdfStart(String date, String time) {
    final d = date.trim().split('.');
    final t = time.trim().split('.');

    if (d.length < 3 || t.length < 2) return null;

    final day = int.tryParse(d[0]) ?? 1;
    final month = int.tryParse(d[1]) ?? 1;
    final yy = int.tryParse(d[2]) ?? 0;

    final hour = int.tryParse(t[0]) ?? 0;
    final minute = int.tryParse(t[1]) ?? 0;
    final second = t.length >= 3 ? (int.tryParse(t[2]) ?? 0) : 0;

    final year = (yy <= 84) ? (2000 + yy) : (1900 + yy);
    return DateTime(year, month, day, hour, minute, second);
  }

  static Future<int> computeTotalSeconds(File edfFile, EdxEdfHeader header) async {
    final bytesPerRecord =
        header.signals.fold<int>(0, (sum, s) => sum + s.samplesPerRecord) * 2;

    final fileLen = await edfFile.length();
    final dataBytes = fileLen - header.headerBytes;
    final computedRecords = dataBytes > 0 ? (dataBytes ~/ bytesPerRecord) : 0;

    final totalRecords = header.numRecords > 0
        ? min(header.numRecords, computedRecords)
        : computedRecords;

    return (totalRecords * header.recordDurationSeconds).floor();
  }

  static Future<List<ImportedEdfSummary>> scan(Directory importsDir) async {
    if (!await importsDir.exists()) return [];

    final edfFiles = <File>[];

    await for (final entity in importsDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.edf')) {
        edfFiles.add(entity);
      }
    }

    // Stable, et agréable à lire
    edfFiles.sort((a, b) => a.path.compareTo(b.path));

    final out = <ImportedEdfSummary>[];

    for (final f in edfFiles) {
      try {
        final header = await EdfHeaderParser.parseHeader(f);
        final start = parseEdfStart(header.startDate, header.startTime);
        final totalSeconds = await computeTotalSeconds(f, header);

        out.add(
          ImportedEdfSummary(
            file: f,
            fileName: f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : f.path,
            numSignals: header.numSignals,
            totalSeconds: totalSeconds,
            start: start,
          ),
        );
      } catch (_) {
        // Si un EDF est corrompu, on l’ignore (pour l’instant).
      }
    }

    // Tri par date (si disponible), sinon par nom
    out.sort((a, b) {
      final ad = a.start;
      final bd = b.start;
      if (ad != null && bd != null) return bd.compareTo(ad); // récent en premier
      if (ad != null) return -1;
      if (bd != null) return 1;
      return a.fileName.compareTo(b.fileName);
    });

    return out;
  }
}
