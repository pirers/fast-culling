import 'package:fast_culling/domain/entities/photo.dart';

/// Interface for recursively scanning a directory for JPEG files.
abstract class FilesystemService {
  /// Scans [rootDirectory] recursively for JPEG files.
  ///
  /// Emits discovered [Photo] objects as they are found. EXIF metadata
  /// extraction is performed by [ExifService]; this service is responsible
  /// only for enumerating file paths and computing file sizes.
  Stream<Photo> scanDirectory(String rootDirectory);
}
