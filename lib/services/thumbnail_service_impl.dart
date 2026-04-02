import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fast_culling/services/thumbnail_service.dart';

class ThumbnailServiceImpl implements ThumbnailService {
  final _cache = <String, Uint8List?>{};

  @override
  Future<Uint8List?> getThumbnail(String absolutePath,
      {int maxDimension = 256}) async {
    final key = '$absolutePath@$maxDimension';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final bytes = await File(absolutePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: maxDimension,
        targetHeight: maxDimension,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final result = byteData?.buffer.asUint8List();
      _cache[key] = result;
      return result;
    } catch (_) {
      _cache[key] = null;
      return null;
    }
  }

  @override
  Future<void> clearCache() async => _cache.clear();
}
