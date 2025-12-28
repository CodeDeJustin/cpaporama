import 'dart:io';
import 'package:archive/archive.dart';

class ZipExtractorResult {
  ZipExtractorResult({
    required this.outputDir,
    required this.extractedFiles,
    required this.edfFiles,
  });

  final Directory outputDir;
  final int extractedFiles;
  final List<File> edfFiles;
}

class ZipExtractor {
  static Future<ZipExtractorResult> extractZipToDir({
    required File zipFile,
    required Directory outputDir,
  }) async {
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    var extractedCount = 0;
    final edfs = <File>[];

    for (final entry in archive) {
      final rawName = entry.name.replaceAll('\\', '/').trim();

      // sécurité simple anti zip-slip
      if (rawName.isEmpty || rawName.contains('..') || rawName.startsWith('/')) {
        continue;
      }

      if (entry.isFile) {
        final outPath = '${outputDir.path}/$rawName';
        final outFile = File(outPath);
        await outFile.parent.create(recursive: true);

        final content = entry.content;
        if (content is List<int>) {
          await outFile.writeAsBytes(content, flush: true);
          extractedCount++;

          if (outFile.path.toLowerCase().endsWith('.edf')) {
            edfs.add(outFile);
          }
        }
      }
    }

    edfs.sort((a, b) => a.path.compareTo(b.path));

    return ZipExtractorResult(
      outputDir: outputDir,
      extractedFiles: extractedCount,
      edfFiles: edfs,
    );
  }
}
