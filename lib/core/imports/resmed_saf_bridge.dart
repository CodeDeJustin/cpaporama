import 'package:flutter/services.dart';

class ResmedSafBridge {
  static const MethodChannel _ch = MethodChannel('cpaporama/saf');

  static Future<String?> pickTree() async {
    return _ch.invokeMethod<String>('pickTree');
  }

  static Future<Map<String, dynamic>> syncLatest({
    required String treeUri,
    required String destBasePath,
  }) async {
    final res = await _ch.invokeMapMethod<String, dynamic>(
      'syncResmedLatest',
      {'treeUri': treeUri, 'destBasePath': destBasePath},
    );
    if (res == null) throw Exception('Réponse native nulle (syncResmedLatest).');
    return res;
  }

  static Future<Map<String, dynamic>> syncLastN({
    required String treeUri,
    required String destBasePath,
    required int n,
  }) async {
    final res = await _ch.invokeMapMethod<String, dynamic>(
      'syncResmedLastN',
      {'treeUri': treeUri, 'destBasePath': destBasePath, 'n': n},
    );
    if (res == null) throw Exception('Réponse native nulle (syncResmedLastN).');
    return res;
  }

  static Future<Map<String, dynamic>> syncRange({
    required String treeUri,
    required String destBasePath,
    required String fromNightKey, // YYYYMMDD
    required String toNightKey,   // YYYYMMDD
  }) async {
    final res = await _ch.invokeMapMethod<String, dynamic>(
      'syncResmedRange',
      {
        'treeUri': treeUri,
        'destBasePath': destBasePath,
        'fromNightKey': fromNightKey,
        'toNightKey': toNightKey,
      },
    );
    if (res == null) throw Exception('Réponse native nulle (syncResmedRange).');
    return res;
  }
}
