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
    this.xOrigin, // <-- NEW: date/heure de départ de la fenêtre
  });

  final String title;
  final List<EdfDataPoint> points;
  final String? unit;
  final double height;

  /// Si fourni, l’axe X affichera l’heure (HH:mm / HH:mm:ss).
  /// Sinon, on affiche des secondes.
  final DateTime? xOrigin;

  String _fmtClock(DateTime dt, {bool withSeconds = false}) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (!withSeconds) return '$hh:$mm';
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('Aucun point à afficher.');
    }

    final spots = points.map((p) => FlSpot(p.tSeconds, p.value)).toList(growable: false);

    final minX = spots.first.x;
    final maxX = spots.last.x;

    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final s in spots) {
      minY = min(minY, s.y);
      maxY = max(maxY, s.y);
    }
    if ((maxY - minY).abs() < 1e-9) {
      maxY += 1;
      minY -= 1;
    }

    final span = (maxX - minX).abs();
    double xInterval;
    if (xOrigin != null) {
      // Labels “humains”
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
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(0)),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  dotData: const FlDotData(show: false),
                  barWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
