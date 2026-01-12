import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/nights/night_repository.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({
    super.key,
    required this.repo,
    required this.range,
    this.limit, // NEW
  });

  final NightRepository repo;
  final DateTimeRange? range;
  final int? limit;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _loading = true;
  List<NightListItem> _items = [];

  String _fmtDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _fmtHhMm(int seconds) {
    final s = max(0, seconds);
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final r = widget.range;
    final items = await widget.repo.listNights(
      from: r?.start,
      to: r?.end,
      limit: (r == null) ? widget.limit : null, // NEW
    );

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.range;

    final totalUse = _items.fold<int>(0, (a, b) => a + b.useSeconds);
    final totalGaps = _items.fold<int>(0, (a, b) => a + b.gapCount);
    final totalGapSeconds = _items.fold<int>(0, (a, b) => a + b.gapSeconds);
    final totalSessions = _items.fold<int>(0, (a, b) => a + b.sessionsCount);

    final unionLabels = <String>{};
    for (final i in _items) {
      unionLabels.addAll(i.labels);
    }

    final headerText = () {
      if (r != null) return '${_fmtDate(r.start)} → ${_fmtDate(r.end)}';
      if (widget.limit != null) return 'Dernières ${widget.limit} nuits';
      return 'Toutes les nuits indexées';
    }();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Plage', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(headerText),
                  const SizedBox(height: 12),
                  Text('Nuits: ${_items.length}'),
                  Text('Utilisation totale: ${_fmtHhMm(totalUse)}'),
                  if (_items.isNotEmpty)
                    Text('Moyenne/nuit: ${_fmtHhMm((totalUse / _items.length).round())}'),
                  const SizedBox(height: 10),
                  Text('Sessions (segments): $totalSessions'),
                  Text('Gaps: $totalGaps (${_fmtHhMm(totalGapSeconds)})'),
                  const SizedBox(height: 10),
                  Text('Labels détectés: ${unionLabels.length}'),
                  if (unionLabels.isNotEmpty)
                    Text(
                      unionLabels.take(12).join(', ') +
                          (unionLabels.length > 12 ? ' …' : ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
