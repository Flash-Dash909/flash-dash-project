import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class DownloadService {
  static Future<void> save({
    required Uint8List bytes,
    required String name,
    required String extension,
    required String mimeType,
  }) async {
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: extension,
      mimeType: MimeType.other,
      customMimeType: mimeType,
    );
  }
}
