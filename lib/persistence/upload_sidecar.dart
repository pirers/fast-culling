import 'dart:convert';
import 'dart:io';

import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:path/path.dart' as p;

/// Reads and writes upload state to `.sftp_uploads.json` in the root of a local folder.
class UploadSidecar {
  static const _filename = '.sftp_uploads.json';

  static Future<Map<String, UploadRecord>> load(String rootDirectory) async {
    try {
      final file = File(p.join(rootDirectory, _filename));
      if (!await file.exists()) return {};
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json.map((key, value) =>
          MapEntry(key, UploadRecord.fromJson(key, value as Map<String, dynamic>)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> save(
      String rootDirectory, Map<String, UploadRecord> records) async {
    try {
      final file = File(p.join(rootDirectory, _filename));
      final json = records.map((key, record) => MapEntry(key, record.toJson()));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
        flush: true,
      );
    } catch (_) {}
  }
}
