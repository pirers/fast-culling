import 'package:fast_culling/domain/algorithms/burst_detector.dart';
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/photo.dart';
import 'package:flutter_test/flutter_test.dart';

Photo _photo(
  String path, {
  DateTime? timestamp,
  int fileSize = 1000,
}) =>
    Photo(
      relativePath: path,
      absolutePath: '/root/$path',
      exifTimestamp: timestamp,
      fileSize: fileSize,
    );

DateTime _ts(int secondsFromEpoch) =>
    DateTime.fromMillisecondsSinceEpoch(secondsFromEpoch * 1000, isUtc: true);

void main() {
  group('detectBursts', () {
    test('empty list returns empty bursts', () {
      final result = detectBursts([], 500);
      expect(result, isEmpty);
    });

    test('single photo with timestamp creates one burst of one frame', () {
      final photos = [_photo('a.jpg', timestamp: _ts(1))];
      final result = detectBursts(photos, 500);
      expect(result.length, 1);
      expect(result.first.frames.length, 1);
    });

    test('single photo without timestamp is excluded', () {
      final photos = [_photo('a.jpg')];
      final result = detectBursts(photos, 500);
      expect(result, isEmpty);
    });

    test('photos with no timestamps are excluded, others grouped normally', () {
      final photos = [
        _photo('no-ts.jpg'),
        _photo('a.jpg', timestamp: _ts(0)),
        _photo('b.jpg', timestamp: _ts(0) + const Duration(milliseconds: 100)),
      ];
      final result = detectBursts(photos, 500);
      expect(result.length, 1);
      expect(result.first.frames.length, 2);
    });

    test('photos at exactly the threshold are in the same burst', () {
      final base = _ts(100);
      final photos = [
        _photo('a.jpg', timestamp: base),
        _photo('b.jpg',
            timestamp: base + const Duration(milliseconds: 500)),
      ];
      final result = detectBursts(photos, 500);
      expect(result.length, 1);
      expect(result.first.frames.length, 2);
    });

    test('photos just over the threshold are split into separate bursts', () {
      final base = _ts(100);
      final photos = [
        _photo('a.jpg', timestamp: base),
        _photo('b.jpg',
            timestamp: base + const Duration(milliseconds: 501)),
      ];
      final result = detectBursts(photos, 500);
      expect(result.length, 2);
      expect(result[0].frames.length, 1);
      expect(result[1].frames.length, 1);
    });

    test('multiple bursts correctly split', () {
      final base = _ts(0);
      final photos = [
        // Burst 1: 3 frames
        _photo('a.jpg', timestamp: base),
        _photo('b.jpg',
            timestamp: base + const Duration(milliseconds: 200)),
        _photo('c.jpg',
            timestamp: base + const Duration(milliseconds: 400)),
        // Gap of 2 s > 500 ms → new burst
        _photo('d.jpg',
            timestamp: base + const Duration(seconds: 2, milliseconds: 400)),
        // Burst 2: 2 frames
        _photo('e.jpg',
            timestamp: base + const Duration(seconds: 2, milliseconds: 700)),
        // Another gap
        _photo('f.jpg',
            timestamp: base + const Duration(seconds: 10)),
      ];
      final result = detectBursts(photos, 500);
      expect(result.length, 3);
      expect(result[0].frames.length, 3);
      expect(result[1].frames.length, 2);
      expect(result[2].frames.length, 1);
    });

    test('burst IDs are stable and have correct prefix', () {
      final base = _ts(0);
      final photos = [
        _photo('img.jpg', timestamp: base),
      ];
      final result = detectBursts(photos, 500);
      expect(result.first.id, startsWith('burst-'));
      // ID suffix is 8 hex characters.
      final suffix = result.first.id.substring('burst-'.length);
      expect(suffix.length, 8);
      expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(suffix), isTrue);
    });

    test('burst IDs are deterministic across calls', () {
      final base = _ts(42);
      final photos = [
        _photo('test/img.jpg', timestamp: base),
      ];
      final id1 = detectBursts(photos, 500).first.id;
      final id2 = detectBursts(photos, 500).first.id;
      expect(id1, equals(id2));
    });

    test('all-null-timestamp list returns empty bursts', () {
      final photos = [
        _photo('a.jpg'),
        _photo('b.jpg'),
        _photo('c.jpg'),
      ];
      expect(detectBursts(photos, 500), isEmpty);
    });

    test('photos are sorted by timestamp before grouping', () {
      final base = _ts(100);
      // Deliberately out of order.
      final photos = [
        _photo('b.jpg',
            timestamp: base + const Duration(milliseconds: 200)),
        _photo('a.jpg', timestamp: base),
        _photo('c.jpg',
            timestamp: base + const Duration(milliseconds: 400)),
      ];
      final result = detectBursts(photos, 500);
      expect(result.length, 1);
      expect(result.first.frames.length, 3);
      // First frame should be the earliest timestamp.
      expect(result.first.frames.first.photo.relativePath, 'a.jpg');
    });
  });
}
