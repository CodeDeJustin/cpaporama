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
    if (res == null) {
      throw Exception('Réponse native nulle (syncResmedLatest).');
    }
    return res;
  }
}