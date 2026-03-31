import 'dart:io';

import 'package:exif/exif.dart';
import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/services/exif_service.dart';
import 'package:fast_culling/services/exif_timestamp_parser.dart';

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

      // Timestamp priority: DateTimeOriginal > DateTimeDigitized > DateTime.
      final rawTs = tags['EXIF DateTimeOriginal']?.printable ??
          tags['EXIF DateTimeDigitized']?.printable ??
          tags['Image DateTime']?.printable;

      // Sub-second fractional part — matches the same priority as above.
      // Cameras store this in SubSecTimeOriginal (e.g. "123" → 123 ms).
      final rawSubSec = tags['EXIF SubSecTimeOriginal']?.printable ??
          tags['EXIF SubSecTimeDigitized']?.printable ??
          tags['EXIF SubSecTime']?.printable;

      final timestamp =
          rawTs != null ? parseExifDateTime(rawTs, subSec: rawSubSec) : null;

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
}
