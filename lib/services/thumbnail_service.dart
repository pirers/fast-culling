import 'dart:typed_data';

/// Interface for generating and caching JPEG thumbnails.
abstract class ThumbnailService {
  /// Returns thumbnail image bytes for the JPEG at [absolutePath].
  ///
  /// [maxDimension] — maximum width or height in pixels (maintains aspect ratio).
  /// Results are cached in memory; a disk cache may be added by implementations.
  Future<Uint8List?> getThumbnail(String absolutePath, {int maxDimension = 256});

  /// Clears in-memory and disk caches.
  Future<void> clearCache();
}
