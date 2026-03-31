import 'dart:io';

import 'package:exif/exif.dart';
import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/services/exif_service.dart';

/// Concrete EXIF extraction using the `exif` package.
class ExifServiceImpl implements ExifService {
  const ExifServiceImpl();

  @override
  Future<Photo> extractMetadata({
    required String relativePath,
    required String absolutePath,
  }) async {
    final file = File(absolutePath);
    int fileSize = 0;
    try {
      fileSize = (await file.stat()).size;
    } catch (_) {}

    try {
      final bytes = await file.readAsBytes();
      final tags = await readExifFromBytes(bytes);

      // Timestamp priority: DateTimeOriginal > DateTimeDigitized > DateTime
      final rawTs = tags['EXIF DateTimeOriginal']?.printable ??
          tags['EXIF DateTimeDigitized']?.printable ??
          tags['Image DateTime']?.printable;

      final timestamp = rawTs != null ? _parseExifDateTime(rawTs) : null;

      return Photo(
        relativePath: relativePath,
        absolutePath: absolutePath,
        exifTimestamp: timestamp,
        starRating: null, // EXIF XMP star ratings are not in EXIF IFD
        fileSize: fileSize,
      );
    } catch (_) {
      return Photo(
        relativePath: relativePath,
        absolutePath: absolutePath,
        fileSize: fileSize,
      );
    }
  }

  /// Parses an EXIF datetime string `"yyyy:MM:dd HH:mm:ss"` to [DateTime].
  DateTime? _parseExifDateTime(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.length < 19) return null;
      // Replace the date colons with dashes so DateTime.parse can handle it.
      final iso =
          '${trimmed.substring(0, 10).replaceAll(':', '-')}T${trimmed.substring(11)}';
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }
}
