import 'dart:convert';
import 'dart:io';

import 'package:fast_culling/domain/entities/upload_record.dart';
import 'package:path/path.dart' as p;

/// Name of the upload-history file placed at the root of the scanned folder.
const _uploadLogFilename = '.sftp_uploads.json';

/// Reads and writes per-file SFTP upload status as a JSON file located at
/// `<localFolder>/.sftp_uploads.json`.
///
/// The file is updated after every successful file upload so that a partial
/// upload session is not lost on app restart.
class UploadLog {
  /// Loads the upload log for [localFolder].
  ///
  /// Returns an empty map if the file does not exist or cannot be parsed.
  static Future<Map<String, UploadRecord>> load(String localFolder) async {
    try {
      final file = File(p.join(localFolder, _uploadLogFilename));
      if (!await file.exists()) return {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map<String, dynamic>) return {};
      final uploads = raw['uploads'];
      if (uploads is! Map<String, dynamic>) return {};
      return {
        for (final e in uploads.entries)
          if (e.value is Map<String, dynamic>)
            e.key: UploadRecord.fromJson(
              e.key,
              e.value as Map<String, dynamic>,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  /// Saves [records] to `<localFolder>/.sftp_uploads.json`.
  static Future<void> save(
    String localFolder,
    Map<String, UploadRecord> records,
  ) async {
    final file = File(p.join(localFolder, _uploadLogFilename));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schema_version': 1,
        'generated_by': 'fast_culling',
        'uploads': {
          for (final r in records.values) r.relativePath: r.toJson(),
        },
      }),
      flush: true,
    );
  }
}
