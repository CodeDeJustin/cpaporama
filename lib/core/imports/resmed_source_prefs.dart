import 'package:shared_preferences/shared_preferences.dart';

class ResmedSourcePrefs {
  static const _kTreeUri = 'resmed_tree_uri';

  static Future<String?> getTreeUri() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTreeUri);
  }

  static Future<void> setTreeUri(String uri) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTreeUri, uri);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTreeUri);
  }
}