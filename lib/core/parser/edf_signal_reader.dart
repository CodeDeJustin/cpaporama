import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'edf_header_parser.dart';

class EdfDataPoint {
  EdfDataPoint(this.tSeconds, this.value);

  final double tSeconds;
  final double value;
}

class EdfSignalSeries {
  EdfSignalSeries({
    required this.label,
    required this.unit,
    required this.sampleRateHz,
    required this.points,
    required this.windowSeconds,
  });

  final String label;
  final String unit;
  final double sampleRateHz;
  final List<EdfDataPoint> points;
  final int windowSeconds;
}

class EdfSignalReader {
  static int findSignalIndex(
      EdxEdfHeader header, {
        List<String> preferContainsLower = const ['flow', 'press', 'pressure'],
      }) {
    final labels = header.signalLabels;
    for (final wanted in preferContainsLower) {
      final idx = labels.indexWhere((l) => l.toLowerCase().contains(wanted));
      if (idx >= 0) return idx;
    }
    return 0;
  }

  static Future<EdfSignalSeries> readSignalSeries({
    required File file,
    required EdxEdfHeader header,
    required int signalIndex,
    int startSeconds = 0,
    int windowSeconds = 30,
    int maxPoints = 3000,
  }) async {
    if (signalIndex < 0 || signalIndex >= header.numSignals) {
      throw RangeError('signalIndex=$signalIndex hors limites.');
    }
    if (header.recordDurationSeconds <= 0) {
      throw FormatException('recordDurationSeconds invalide: ${header.recordDurationSeconds}');
    }

    final sig = header.signals[signalIndex];
    final samplesInRecord = sig.samplesPerRecord;
    if (samplesInRecord <= 0) {
      throw FormatException('samplesPerRecord invalide pour ${sig.label}: $samplesInRecord');
    }

    final bytesPerRecord =
        header.signals.fold<int>(0, (sum, s) => sum + s.samplesPerRecord) * 2;
    if (bytesPerRecord <= 0) {
      throw FormatException('bytesPerRecord invalide: $bytesPerRecord');
    }

    final fileLen = await file.length();
    final dataBytes = fileLen - header.headerBytes;
    final computedRecords = dataBytes > 0 ? (dataBytes ~/ bytesPerRecord) : 0;
    final totalRecords = header.numRecords > 0
        ? min(header.numRecords, computedRecords)
        : computedRecords;

    if (totalRecords <= 0) {
      throw FormatException(
        'Aucun record EDF lisible (numRecords=${header.numRecords}, computed=$computedRecords).',
      );
    }

    final sampleRateHz = samplesInRecord / header.recordDurationSeconds;
    final totalSamplesAvailable = totalRecords * samplesInRecord;

    final startSample = max(0, (startSeconds * sampleRateHz).floor());
    if (startSample >= totalSamplesAvailable) {
      throw FormatException('startSeconds=$startSeconds trop grand (dépasse la durée du fichier).');
    }

    final availableFromStart = totalSamplesAvailable - startSample;
    final wantedSamples = min(availableFromStart, (windowSeconds * sampleRateHz).ceil());

    // Downsample min/max: ~maxPoints points => ~maxPoints/2 buckets
    final targetBuckets = max(1, maxPoints ~/ 2);
    final bucketSize = max(1, (wantedSamples / targetBuckets).ceil());

    final priorSamples = header.signals
        .take(signalIndex)
        .fold<int>(0, (sum, s) => sum + s.samplesPerRecord);

    final scaleDen = (sig.digitalMax - sig.digitalMin);
    final scaleNum = (sig.physicalMax - sig.physicalMin);

    double toPhysical(int d) {
      if (scaleDen == 0) return d.toDouble();
      return ((d - sig.digitalMin) * scaleNum / scaleDen) + sig.physicalMin;
    }

    final points = <EdfDataPoint>[];

    // bucket state (indices relatifs à la fenêtre)
    int currentBucket = 0;
    int bucketEndIndex = bucketSize - 1;

    double? minV, maxV;
    double? minT, maxT;

    void flushBucket() {
      if (minV == null || maxV == null || minT == null || maxT == null) return;

      if (minT! <= maxT!) {
        points.add(EdfDataPoint(minT!, minV!));
        points.add(EdfDataPoint(maxT!, maxV!));
      } else {
        points.add(EdfDataPoint(maxT!, maxV!));
        points.add(EdfDataPoint(minT!, minV!));
      }
    }

    final startRecord = startSample ~/ samplesInRecord;
    final startOffsetInRecord = startSample % samplesInRecord;

    final raf = await file.open();
    try {
      for (var recordIndex = startRecord; recordIndex < totalRecords; recordIndex++) {
        final recordBase = header.headerBytes + (recordIndex * bytesPerRecord);
        final offsetBytes = recordBase + (priorSamples * 2);
        final wantBytes = samplesInRecord * 2;

        await raf.setPosition(offsetBytes);
        final raw = await raf.read(wantBytes);
        if (raw.length != wantBytes) break;

        final bd = ByteData.sublistView(Uint8List.fromList(raw));

        final iStart = (recordIndex == startRecord) ? startOffsetInRecord : 0;

        for (var i = iStart; i < samplesInRecord; i++) {
          final globalIndex = (recordIndex * samplesInRecord) + i;
          final relIndex = globalIndex - startSample;

          if (relIndex >= wantedSamples) {
            flushBucket();
            // coupe proprement
            if (points.length > maxPoints) {
              points.removeRange(maxPoints, points.length);
            }
            return EdfSignalSeries(
              label: sig.label,
              unit: sig.physicalDimension,
              sampleRateHz: sampleRateHz,
              points: points,
              windowSeconds: windowSeconds,
            );
          }

          while (relIndex > bucketEndIndex) {
            flushBucket();
            currentBucket++;
            bucketEndIndex = ((currentBucket + 1) * bucketSize) - 1;

            minV = maxV = null;
            minT = maxT = null;
          }

          final d = bd.getInt16(i * 2, Endian.little);
          final v = toPhysical(d);

          // temps relatif à la fenêtre (0..windowSeconds)
          final tAbs = (recordIndex * header.recordDurationSeconds) + (i / sampleRateHz);
          final t = tAbs - startSeconds;

          if (minV == null || v < minV!) {
            minV = v;
            minT = t;
          }
          if (maxV == null || v > maxV!) {
            maxV = v;
            maxT = t;
          }
        }
      }

      flushBucket();
    } finally {
      await raf.close();
    }

    if (points.length > maxPoints) {
      points.removeRange(maxPoints, points.length);
    }

    return EdfSignalSeries(
      label: sig.label,
      unit: sig.physicalDimension,
      sampleRateHz: sampleRateHz,
      points: points,
      windowSeconds: windowSeconds,
    );
  }

  static Future<EdfSignalSeries> readSignalSeriesF({
    required File file,
    required EdxEdfHeader header,
    required int signalIndex,
    double startTimeSeconds = 0,
    double windowSeconds = 30,
    int maxPoints = 3000,
  }) async {
    if (signalIndex < 0 || signalIndex >= header.numSignals) {
      throw RangeError('signalIndex=$signalIndex hors limites.');
    }
    if (header.recordDurationSeconds <= 0) {
      throw FormatException('recordDurationSeconds invalide: ${header.recordDurationSeconds}');
    }
    if (windowSeconds <= 0) {
      throw FormatException('windowSeconds invalide: $windowSeconds');
    }

    final sig = header.signals[signalIndex];
    final samplesInRecord = sig.samplesPerRecord;
    if (samplesInRecord <= 0) {
      throw FormatException('samplesPerRecord invalide pour ${sig.label}: $samplesInRecord');
    }

    final bytesPerRecord =
        header.signals.fold<int>(0, (sum, s) => sum + s.samplesPerRecord) * 2;
    if (bytesPerRecord <= 0) {
      throw FormatException('bytesPerRecord invalide: $bytesPerRecord');
    }

    final fileLen = await file.length();
    final dataBytes = fileLen - header.headerBytes;
    final computedRecords = dataBytes > 0 ? (dataBytes ~/ bytesPerRecord) : 0;
    final totalRecords = header.numRecords > 0
        ? min(header.numRecords, computedRecords)
        : computedRecords;

    if (totalRecords <= 0) {
      throw FormatException(
        'Aucun record EDF lisible (numRecords=${header.numRecords}, computed=$computedRecords).',
      );
    }

    final sampleRateHz = samplesInRecord / header.recordDurationSeconds;
    final totalSamplesAvailable = totalRecords * samplesInRecord;

    // IMPORTANT: ceil => 1er sample >= startTimeSeconds, donc t >= 0
    final startSample = max(0, (startTimeSeconds * sampleRateHz).ceil());
    if (startSample >= totalSamplesAvailable) {
      throw FormatException('startTimeSeconds=$startTimeSeconds trop grand (dépasse la durée du fichier).');
    }

    final availableFromStart = totalSamplesAvailable - startSample;
    final wantedSamples = min(availableFromStart, (windowSeconds * sampleRateHz).ceil());

    // Downsample min/max: ~maxPoints points => ~maxPoints/2 buckets
    final targetBuckets = max(1, maxPoints ~/ 2);
    final bucketSize = max(1, (wantedSamples / targetBuckets).ceil());

    final priorSamples = header.signals
        .take(signalIndex)
        .fold<int>(0, (sum, s) => sum + s.samplesPerRecord);

    final scaleDen = (sig.digitalMax - sig.digitalMin);
    final scaleNum = (sig.physicalMax - sig.physicalMin);

    double toPhysical(int d) {
      if (scaleDen == 0) return d.toDouble();
      return ((d - sig.digitalMin) * scaleNum / scaleDen) + sig.physicalMin;
    }

    final points = <EdfDataPoint>[];

    int currentBucket = 0;
    int bucketEndIndex = bucketSize - 1;

    double? minV, maxV;
    double? minT, maxT;

    void flushBucket() {
      if (minV == null || maxV == null || minT == null || maxT == null) return;

      if (minT! <= maxT!) {
        points.add(EdfDataPoint(minT!, minV!));
        points.add(EdfDataPoint(maxT!, maxV!));
      } else {
        points.add(EdfDataPoint(maxT!, maxV!));
        points.add(EdfDataPoint(minT!, minV!));
      }
    }

    final startRecord = startSample ~/ samplesInRecord;
    final startOffsetInRecord = startSample % samplesInRecord;

    final raf = await file.open();
    try {
      for (var recordIndex = startRecord; recordIndex < totalRecords; recordIndex++) {
        final recordBase = header.headerBytes + (recordIndex * bytesPerRecord);
        final offsetBytes = recordBase + (priorSamples * 2);
        final wantBytes = samplesInRecord * 2;

        await raf.setPosition(offsetBytes);
        final raw = await raf.read(wantBytes);
        if (raw.length != wantBytes) break;

        final bd = ByteData.sublistView(Uint8List.fromList(raw));

        final iStart = (recordIndex == startRecord) ? startOffsetInRecord : 0;

        for (var i = iStart; i < samplesInRecord; i++) {
          final globalIndex = (recordIndex * samplesInRecord) + i;
          final relIndex = globalIndex - startSample;

          if (relIndex >= wantedSamples) {
            flushBucket();
            if (points.length > maxPoints) {
              points.removeRange(maxPoints, points.length);
            }
            return EdfSignalSeries(
              label: sig.label,
              unit: sig.physicalDimension,
              sampleRateHz: sampleRateHz,
              points: points,
              windowSeconds: windowSeconds.ceil(),
            );
          }

          while (relIndex > bucketEndIndex) {
            flushBucket();
            currentBucket++;
            bucketEndIndex = ((currentBucket + 1) * bucketSize) - 1;

            minV = maxV = null;
            minT = maxT = null;
          }

          final d = bd.getInt16(i * 2, Endian.little);
          final v = toPhysical(d);

          // temps relatif à startTimeSeconds (0..windowSeconds)
          final tAbs = globalIndex / sampleRateHz;
          final t = tAbs - startTimeSeconds;

          if (minV == null || v < minV!) {
            minV = v;
            minT = t;
          }
          if (maxV == null || v > maxV!) {
            maxV = v;
            maxT = t;
          }
        }
      }

      flushBucket();
    } finally {
      await raf.close();
    }

    if (points.length > maxPoints) {
      points.removeRange(maxPoints, points.length);
    }

    return EdfSignalSeries(
      label: sig.label,
      unit: sig.physicalDimension,
      sampleRateHz: sampleRateHz,
      points: points,
      windowSeconds: windowSeconds.ceil(),
    );
  }


}

