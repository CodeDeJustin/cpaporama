import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class EdxEdfSignal {
  EdxEdfSignal({
    required this.label,
    required this.transducer,
    required this.physicalDimension,
    required this.physicalMin,
    required this.physicalMax,
    required this.digitalMin,
    required this.digitalMax,
    required this.prefiltering,
    required this.samplesPerRecord,
    required this.reserved,
  });

  final String label;
  final String transducer;
  final String physicalDimension;
  final double physicalMin;
  final double physicalMax;
  final int digitalMin;
  final int digitalMax;
  final String prefiltering;
  final int samplesPerRecord;
  final String reserved;
}

class EdxEdfHeader {
  EdxEdfHeader({
    required this.version,
    required this.patientId,
    required this.recordingId,
    required this.startDate,
    required this.startTime,
    required this.headerBytes,
    required this.numRecords,
    required this.recordDurationSeconds,
    required this.numSignals,
    required this.signals,
  });

  final String version;
  final String patientId;
  final String recordingId;
  final String startDate;
  final String startTime;
  final int headerBytes;
  final int numRecords;
  final double recordDurationSeconds;
  final int numSignals;
  final List<EdxEdfSignal> signals;

  List<String> get signalLabels => signals.map((s) => s.label).toList();
}

class EdfHeaderParser {
  static Future<EdxEdfHeader> parseHeader(File file) async {
    final raf = await file.open();
    try {
      final fixed = await raf.read(256);
      if (fixed.length < 256) {
        throw FormatException('Fichier trop petit pour un header EDF.');
      }

      String _fixedField(int start, int len) =>
          latin1.decode(fixed.sublist(start, start + len)).trim();

      final version = _fixedField(0, 8);
      final patientId = _fixedField(8, 80);
      final recordingId = _fixedField(88, 80);
      final startDate = _fixedField(168, 8);
      final startTime = _fixedField(176, 8);
      final headerBytesStr = _fixedField(184, 8);
      final numRecordsStr = _fixedField(236, 8);
      final recordDurStr = _fixedField(244, 8);
      final numSignalsStr = _fixedField(252, 4);

      final headerBytes = int.tryParse(headerBytesStr) ?? 0;
      final numRecords = int.tryParse(numRecordsStr) ?? 0;
      final recordDurationSeconds = double.tryParse(recordDurStr) ?? 0.0;
      final numSignals = int.tryParse(numSignalsStr) ?? 0;

      if (headerBytes <= 0 || numSignals <= 0) {
        throw FormatException(
          'Header EDF invalide (headerBytes=$headerBytes, numSignals=$numSignals).',
        );
      }

      final remaining = headerBytes - 256;
      if (remaining < 0) {
        throw FormatException('Header EDF invalide (headerBytes trop petit).');
      }

      final rest = remaining > 0 ? await raf.read(remaining) : Uint8List(0);
      if (rest.length != remaining) {
        throw FormatException('Header EDF incomplet (partie signaux).');
      }

      List<String> _readStringBlock(int fieldLen, int offset) {
        final out = <String>[];
        final need = numSignals * fieldLen;
        if (offset + need > rest.length) {
          throw FormatException('Header EDF incomplet (bloc string len=$fieldLen).');
        }
        for (var i = 0; i < numSignals; i++) {
          final start = offset + (i * fieldLen);
          out.add(latin1.decode(rest.sublist(start, start + fieldLen)).trim());
        }
        return out;
      }

      List<int> _readIntBlock(int fieldLen, int offset) {
        final out = <int>[];
        final strings = _readStringBlock(fieldLen, offset);
        for (final s in strings) {
          out.add(int.tryParse(s) ?? 0);
        }
        return out;
      }

      List<double> _readDoubleBlock(int fieldLen, int offset) {
        final out = <double>[];
        final strings = _readStringBlock(fieldLen, offset);
        for (final s in strings) {
          out.add(double.tryParse(s) ?? 0.0);
        }
        return out;
      }

      var p = 0;
      final labels = _readStringBlock(16, p);
      p += numSignals * 16;

      final transducers = _readStringBlock(80, p);
      p += numSignals * 80;

      final dimensions = _readStringBlock(8, p);
      p += numSignals * 8;

      final physMins = _readDoubleBlock(8, p);
      p += numSignals * 8;

      final physMaxs = _readDoubleBlock(8, p);
      p += numSignals * 8;

      final digMins = _readIntBlock(8, p);
      p += numSignals * 8;

      final digMaxs = _readIntBlock(8, p);
      p += numSignals * 8;

      final prefilters = _readStringBlock(80, p);
      p += numSignals * 80;

      final samplesPerRecord = _readIntBlock(8, p);
      p += numSignals * 8;

      final reserved = _readStringBlock(32, p);
      p += numSignals * 32;

      final signals = List<EdxEdfSignal>.generate(numSignals, (i) {
        return EdxEdfSignal(
          label: labels[i],
          transducer: transducers[i],
          physicalDimension: dimensions[i],
          physicalMin: physMins[i],
          physicalMax: physMaxs[i],
          digitalMin: digMins[i],
          digitalMax: digMaxs[i],
          prefiltering: prefilters[i],
          samplesPerRecord: samplesPerRecord[i],
          reserved: reserved[i],
        );
      });

      return EdxEdfHeader(
        version: version,
        patientId: patientId,
        recordingId: recordingId,
        startDate: startDate,
        startTime: startTime,
        headerBytes: headerBytes,
        numRecords: numRecords,
        recordDurationSeconds: recordDurationSeconds,
        numSignals: numSignals,
        signals: signals,
      );
    } finally {
      await raf.close();
    }
  }
}
