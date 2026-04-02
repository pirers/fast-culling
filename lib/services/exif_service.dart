import 'package:fast_culling/domain/entities/photo.dart';

/// Interface for extracting EXIF metadata from JPEG files.
abstract class ExifService {
  /// Extracts [Photo] metadata from the file at [absolutePath].
  ///
  /// Returns a [Photo] with [Photo.exifTimestamp] and [Photo.starRating]
  /// populated from EXIF data when available. Never throws; returns a
  /// [Photo] with null fields on failure.
  Future<Photo> extractMetadata({
    required String relativePath,
    required String absolutePath,
  });
}
