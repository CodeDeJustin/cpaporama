import 'dart:collection';

import 'night_signal_reader.dart';

class NightWindowCache {
  NightWindowCache({this.maxEntries = 120});

  final int maxEntries;

  final _lru = LinkedHashMap<String, NightWindowReadResult>();
  final _inflight = <String, Future<NightWindowReadResult>>{};

  Future<NightWindowReadResult> getOrLoad(
      String key,
      Future<NightWindowReadResult> Function() loader,
      ) {
    final hit = _lru.remove(key);
    if (hit != null) {
      // refresh LRU
      _lru[key] = hit;
      return Future.value(hit);
    }

    final pending = _inflight[key];
    if (pending != null) return pending;

    final f = loader().then((res) {
      _inflight.remove(key);
      _lru[key] = res;

      while (_lru.length > maxEntries) {
        _lru.remove(_lru.keys.first);
      }
      return res;
    }).catchError((e) {
      _inflight.remove(key);
      throw e;
    });

    _inflight[key] = f;
    return f;
  }
}
