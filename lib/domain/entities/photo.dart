/// Represents a discovered JPEG with its EXIF metadata.
class Photo {
  final String relativePath;
  final String absolutePath;

  /// DateTimeOriginal preferred; fallback to DateTimeDigitized / CreateDate.
  final DateTime? exifTimestamp;

  /// EXIF star rating (1–5), null if not set.
  final int? starRating;

  final int fileSize;

  const Photo({
    required this.relativePath,
    required this.absolutePath,
    this.exifTimestamp,
    this.starRating,
    required this.fileSize,
  });

  @override
  String toString() =>
      'Photo(relativePath: $relativePath, exifTimestamp: $exifTimestamp, starRating: $starRating)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Photo &&
          runtimeType == other.runtimeType &&
          relativePath == other.relativePath &&
          absolutePath == other.absolutePath;

  @override
  int get hashCode => Object.hash(relativePath, absolutePath);
}
