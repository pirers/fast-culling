import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fast_culling/services/thumbnail_service.dart';

class ThumbnailServiceImpl implements ThumbnailService {
  static const _maxCacheEntries = 500;
  final _cache = <String, Uint8List?>{};
  final _insertionOrder = <String>[];

  void _put(String key, Uint8List? value) {
    if (_cache.containsKey(key)) return;
    if (_cache.length >= _maxCacheEntries) {
      final oldest = _insertionOrder.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = value;
    _insertionOrder.add(key);
  }

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
      _put(key, result);
      return result;
    } catch (_) {
      _put(key, null);
      return null;
    }
  }

  @override
  Future<void> clearCache() async {
    _cache.clear();
    _insertionOrder.clear();
  }
}
