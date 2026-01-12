class TimeViewport {
  TimeViewport({
    required this.centerSeconds,
    required this.spanSeconds,
    this.cursorSeconds,
  });

  double centerSeconds; // centre visible (sec depuis nightStart)
  double spanSeconds;   // largeur visible (sec)
  double? cursorSeconds;

  double get start => centerSeconds - spanSeconds / 2.0;
  double get end => centerSeconds + spanSeconds / 2.0;

  void clampTo(double min, double max) {
    if (max <= min) {
      centerSeconds = min;
      spanSeconds = 1;
      return;
    }

    final maxSpan = (max - min);
    if (spanSeconds > maxSpan) spanSeconds = maxSpan;

    final half = spanSeconds / 2.0;
    final lo = min + half;
    final hi = max - half;

    if (lo >= hi) {
      centerSeconds = (min + max) / 2.0;
    } else {
      centerSeconds = centerSeconds.clamp(lo, hi);
    }
  }
}
