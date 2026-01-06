import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/imports/resmed_night_catalog.dart';
import '../../core/parser/edf_header_parser.dart';

class ResmedNightDetailsScreen extends StatefulWidget {
  const ResmedNightDetailsScreen({
    super.key,
    required this.night,
  });

  final ResmedNightSummary night;

  @override
  State<ResmedNightDetailsScreen> createState() => _ResmedNightDetailsScreenState();
}

class _ResmedNightDetailsScreenState extends State<ResmedNightDetailsScreen> {
  final Map<String, int?> _durBySessionKey = {};
  bool _loadingDurations = true;

  String _fmtClock(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _fmtDuration(int? seconds) {
    if (seconds == null) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h <= 0) return '${m}m';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Future<int?> _estimateTotalSeconds(File edfFile) async {
    try {
      final header = await EdfHeaderParser.parseHeader(edfFile);

      final bytesPerRecord =
          header.signals.fold<int>(0, (sum, s) => sum + s.samplesPerRecord) * 2;

      final fileLen = await edfFile.length();
      final dataBytes = fileLen - header.headerBytes;
      final computedRecords = dataBytes > 0 ? (dataBytes ~/ bytesPerRecord) : 0;

      final totalRecords = header.numRecords > 0
          ? min(header.numRecords, computedRecords)
          : computedRecords;

      final totalSeconds = (totalRecords * header.recordDurationSeconds).floor();
      return totalSeconds > 0 ? totalSeconds : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDurations();
  }

  Future<void> _loadDurations() async {
    setState(() => _loadingDurations = true);

    for (final seg in widget.night.segments) {
      final secs = seg.totalSeconds ?? await _estimateTotalSeconds(seg.bestFile);
      _durBySessionKey[seg.sessionKey] = secs;
      if (!mounted) return;
      setState(() {}); // update progress “au fil de l’eau”
    }

    if (!mounted) return;
    setState(() => _loadingDurations = false);
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.night;
    final title = 'Nuit ${_fmtDate(night.nightDate)}';

    final primary = night.primarySegment;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text('Segments: ${night.segmentsCount}'),
                  Text('Fenêtre: ${_fmtClock(night.start)} → ${_fmtClock(night.end)}'),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop<File>(context, primary.bestFile),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Ouvrir le segment principal'),
                  ),
                  if (_loadingDurations) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text('Segments', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          ...night.segments.map((s) {
            final dur = _durBySessionKey[s.sessionKey];
            final types = s.types.join(', ');
            final when = '${_fmtClock(s.start)} • ${s.sessionKey}';
            return Card(
              child: ListTile(
                title: Text(when),
                subtitle: Text('Durée: ${_fmtDuration(dur)} • Types: $types • Choix: ${s.bestType}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop<File>(context, s.bestFile),
              ),
            );
          }),
        ],
      ),
    );
  }
}
