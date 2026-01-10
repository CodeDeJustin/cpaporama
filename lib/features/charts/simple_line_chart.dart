import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/parser/edf_signal_reader.dart';

class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.title,
    required this.points,
    this.unit,
    this.height = 220,
    this.xOrigin,
    this.xMin,
    this.xMax,
  });

  final String title;
  final List<EdfDataPoint> points;
  final String? unit;
  final double height;

  /// Si fourni, l’axe X affichera l’heure (HH:mm / HH:mm:ss).
  /// Sinon, on affiche des secondes.
  final DateTime? xOrigin;

  /// Overrides pour forcer l’axe X (utile si début/fin de fenêtre sont dans un gap).
  final double? xMin;
  final double? xMax;

  String _fmtClock(DateTime dt, {bool withSeconds = false}) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (!withSeconds) return '$hh:$mm';
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    // 1) split points en "chunks" (NaN = gap)
    final chunks = <List<FlSpot>>[];
    var current = <FlSpot>[];

    for (final p in points) {
      if (p.value.isNaN) {
        if (current.isNotEmpty) {
          chunks.add(current);
          current = <FlSpot>[];
        }
        continue;
      }
      current.add(FlSpot(p.tSeconds, p.value));
    }
    if (current.isNotEmpty) chunks.add(current);

    if (chunks.isEmpty) {
      return const Text('Aucun point à afficher.');
    }

    // 2) min/max X
    final derivedMinX = chunks.first.first.x;
    final derivedMaxX = chunks.last.last.x;

    final minX = xMin ?? derivedMinX;
    final maxX = xMax ?? derivedMaxX;

    // 3) min/max Y (sur tous les chunks)
    double minY = chunks.first.first.y;
    double maxY = chunks.first.first.y;

    for (final c in chunks) {
      for (final s in c) {
        minY = min(minY, s.y);
        maxY = max(maxY, s.y);
      }
    }

    if ((maxY - minY).abs() < 1e-9) {
      maxY += 1;
      minY -= 1;
    }

    final span = (maxX - minX).abs();
    double xInterval;

    if (xOrigin != null) {
      if (span <= 60) {
        xInterval = 10; // 10s
      } else if (span <= 300) {
        xInterval = 60; // 1 min
      } else if (span <= 1800) {
        xInterval = 300; // 5 min
      } else {
        xInterval = 900; // 15 min
      }
    } else {
      xInterval = span > 0 ? span / 4 : 1;
    }

    Widget xLabel(double value) {
      if (xOrigin == null) {
        return Text(value.toStringAsFixed(0));
      }
      final withSeconds = span <= 60;
      final dt = xOrigin!.add(Duration(seconds: value.round()));
      return Text(_fmtClock(dt, withSeconds: withSeconds));
    }

    final bars = chunks
        .map(
          (spots) => LineChartBarData(
        spots: spots,
        isCurved: false,
        dotData: const FlDotData(show: false),
        barWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unit == null || unit!.isEmpty ? title : '$title ($unit)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: true),
              titlesData: FlTitlesData(
                topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: xInterval,
                    getTitlesWidget: (value, meta) => xLabel(value),
                  ),
                  axisNameWidget: Text(xOrigin != null ? 'heure' : 's'),
                  axisNameSize: 16,
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    interval: (maxY - minY) > 0 ? (maxY - minY) / 4 : 1,
                    getTitlesWidget: (value, meta) =>
                        Text(value.toStringAsFixed(0)),
                  ),
                ),
              ),
              lineBarsData: bars,
            ),
          ),
        ),
      ],
    );
  }
}
