import 'dart:collection';

/// Lightweight rolling-average FPS counter.
/// Call [onFrame] once per render frame, then read [fps].
class FpsCounter {
  final int _windowSize;
  final Queue<DateTime> _frameTimes = Queue();

  FpsCounter({this._windowSize = 60});

  /// Call this every frame (e.g. in build() or a Ticker callback).
  void onFrame() {
    final now = DateTime.now();
    _frameTimes.addLast(now);
    if (_frameTimes.length > _windowSize) {
      _frameTimes.removeFirst();
    }
  }

  /// Rolling average FPS over the last [_windowSize] frames.
  double get fps {
    if (_frameTimes.length < 2) return 0;
    final span = _frameTimes.last
        .difference(_frameTimes.first)
        .inMicroseconds;
    if (span <= 0) return 0;
    return (_frameTimes.length - 1) / (span / 1e6);
  }

  void reset() => _frameTimes.clear();
}
