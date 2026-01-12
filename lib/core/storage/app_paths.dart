import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  static Future<Directory> importsRoot() async {
    final appDocs = await getApplicationDocumentsDirectory();
    return Directory('${appDocs.path}/imports');
  }
}
