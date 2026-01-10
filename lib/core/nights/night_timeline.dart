import 'dart:math';

import '../imports/resmed_session_catalog.dart';

class NightTimelineSegment {
  NightTimelineSegment({
    required this.session,
    required this.offsetSeconds,
    required this.durationSeconds,
  });

  final ResmedSessionSummary session;

  /// Début du segment dans la nuit (secondes depuis nightStart)
  final int offsetSeconds;

  /// Durée du segment (secondes)
  final int durationSeconds;

  int get endOffsetSeconds => offsetSeconds + durationSeconds;
}

class NightTimeline {
  NightTimeline({
    required this.nightStart,
    required this.totalSeconds,
    required this.segments,
  });

  final DateTime nightStart;
  final int totalSeconds;
  final List<NightTimelineSegment> segments;

  NightTimelineSegment? segmentAt(int tSeconds) {
    for (final s in segments) {
      if (tSeconds >= s.offsetSeconds && tSeconds < s.endOffsetSeconds) {
        return s;
      }
    }
    return null;
  }

  static NightTimeline build({
    required DateTime nightStart,
    required List<NightTimelineSegment> segments,
    int? fallbackTotalSeconds,
  }) {
    int best = fallbackTotalSeconds ?? 0;
    for (final s in segments) {
      best = max(best, s.endOffsetSeconds);
    }
    return NightTimeline(
      nightStart: nightStart,
      totalSeconds: best,
      segments: segments..sort((a, b) => a.offsetSeconds.compareTo(b.offsetSeconds)),
    );
  }
}
