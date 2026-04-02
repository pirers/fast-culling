import 'dart:io';

import 'package:fast_culling/domain/entities/photo.dart';
import 'package:fast_culling/services/filesystem_service.dart';
import 'package:path/path.dart' as p;

/// Concrete implementation that recursively scans a directory for JPEG files.
///
/// Yields [Photo] objects with file-system information only (no EXIF).
/// EXIF enrichment is the responsibility of [ExifService].
class FilesystemServiceImpl implements FilesystemService {
  const FilesystemServiceImpl();

  @override
  Stream<Photo> scanDirectory(String rootDirectory) async* {
    final root = Directory(rootDirectory);
    await for (final entity
        in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final lower = entity.path.toLowerCase();
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
          int size = 0;
          try {
            size = (await entity.stat()).size;
          } catch (_) {}
          final relative = p.relative(entity.path, from: rootDirectory);
          yield Photo(
            relativePath: relative,
            absolutePath: entity.path,
            fileSize: size,
          );
        }
      }
    }
  }
}
