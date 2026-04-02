import 'package:fast_culling/domain/algorithms/crop_interpolator.dart';
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/crop_rect.dart';
import 'package:fast_culling/domain/entities/photo.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

Photo _photo(String path) => Photo(
      relativePath: path,
      absolutePath: '/root/$path',
      fileSize: 1000,
    );

BurstFrame _frame({
  required String path,
  bool isKeyframe = false,
  CropRect? crop,
}) =>
    BurstFrame(
      photo: _photo(path),
      isKeyframe: isKeyframe,
      crop: crop,
    );

const _cropA = CropRect(x: 0.0, y: 0.0, w: 0.5, h: 0.5);
const _cropB = CropRect(x: 0.5, y: 0.5, w: 1.0, h: 1.0);

Burst _burst(List<BurstFrame> frames) =>
    Burst(id: 'burst-test0001', frames: frames);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('interpolateCrop', () {
    test('no keyframes returns null for any frame index', () {
      final burst = _burst([
        _frame(path: 'a.jpg'),
        _frame(path: 'b.jpg'),
        _frame(path: 'c.jpg'),
      ]);
      expect(interpolateCrop(burst, 0), isNull);
      expect(interpolateCrop(burst, 1), isNull);
      expect(interpolateCrop(burst, 2), isNull);
    });

    test('single keyframe returns that keyframe crop for all frame indices', () {
      final burst = _burst([
        _frame(path: 'a.jpg'),
        _frame(path: 'b.jpg', isKeyframe: true, crop: _cropA),
        _frame(path: 'c.jpg'),
      ]);
      expect(interpolateCrop(burst, 0), equals(_cropA)); // before keyframe
      expect(interpolateCrop(burst, 1), equals(_cropA)); // at keyframe
      expect(interpolateCrop(burst, 2), equals(_cropA)); // after keyframe
    });

    test('frame before first keyframe returns first keyframe crop', () {
      final burst = _burst([
        _frame(path: 'a.jpg'),
        _frame(path: 'b.jpg'),
        _frame(path: 'c.jpg', isKeyframe: true, crop: _cropA),
        _frame(path: 'd.jpg', isKeyframe: true, crop: _cropB),
      ]);
      expect(interpolateCrop(burst, 0), equals(_cropA));
      expect(interpolateCrop(burst, 1), equals(_cropA));
    });

    test('frame after last keyframe returns last keyframe crop', () {
      final burst = _burst([
        _frame(path: 'a.jpg', isKeyframe: true, crop: _cropA),
        _frame(path: 'b.jpg', isKeyframe: true, crop: _cropB),
        _frame(path: 'c.jpg'),
        _frame(path: 'd.jpg'),
      ]);
      expect(interpolateCrop(burst, 2), equals(_cropB));
      expect(interpolateCrop(burst, 3), equals(_cropB));
    });

    test('linear interpolation at midpoint between two keyframes', () {
      // Keyframe at index 0 (cropA) and at index 4 (cropB); midpoint = 2.
      final burst = _burst([
        _frame(path: 'a.jpg', isKeyframe: true, crop: _cropA), // index 0
        _frame(path: 'b.jpg'),
        _frame(path: 'c.jpg'),                                  // index 2 — midpoint
        _frame(path: 'd.jpg'),
        _frame(path: 'e.jpg', isKeyframe: true, crop: _cropB), // index 4
      ]);

      final mid = interpolateCrop(burst, 2);
      expect(mid, isNotNull);
      // t = 2/4 = 0.5 → each component is the average of A and B.
      const expected = CropRect(x: 0.25, y: 0.25, w: 0.75, h: 0.75);
      expect(mid!.x, closeTo(expected.x, 1e-10));
      expect(mid.y, closeTo(expected.y, 1e-10));
      expect(mid.w, closeTo(expected.w, 1e-10));
      expect(mid.h, closeTo(expected.h, 1e-10));
    });

    test('interpolation at first keyframe index returns first keyframe crop', () {
      final burst = _burst([
        _frame(path: 'a.jpg', isKeyframe: true, crop: _cropA), // index 0
        _frame(path: 'b.jpg'),
        _frame(path: 'c.jpg', isKeyframe: true, crop: _cropB), // index 2
      ]);
      expect(interpolateCrop(burst, 0), equals(_cropA));
    });

    test('interpolation at last keyframe index returns last keyframe crop', () {
      final burst = _burst([
        _frame(path: 'a.jpg', isKeyframe: true, crop: _cropA), // index 0
        _frame(path: 'b.jpg'),
        _frame(path: 'c.jpg', isKeyframe: true, crop: _cropB), // index 2
      ]);
      expect(interpolateCrop(burst, 2), equals(_cropB));
    });

    test('keyframe without crop is skipped in interpolation', () {
      // index 0 is a keyframe but has no crop — only index 2 has a crop.
      final burst = _burst([
        _frame(path: 'a.jpg', isKeyframe: true),        // no crop
        _frame(path: 'b.jpg'),
        _frame(path: 'c.jpg', isKeyframe: true, crop: _cropB),
      ]);
      // Only one effective keyframe (index 2) → all frames return _cropB.
      expect(interpolateCrop(burst, 0), equals(_cropB));
      expect(interpolateCrop(burst, 1), equals(_cropB));
      expect(interpolateCrop(burst, 2), equals(_cropB));
    });

    test('multiple keyframe segments interpolate independently', () {
      const cropC = CropRect(x: 1.0, y: 1.0, w: 0.5, h: 0.5);
      // Keyframes at indices 0, 2, 4.
      final burst = _burst([
        _frame(path: 'a.jpg', isKeyframe: true, crop: _cropA), // 0
        _frame(path: 'b.jpg'),                                  // 1
        _frame(path: 'c.jpg', isKeyframe: true, crop: _cropB), // 2
        _frame(path: 'd.jpg'),                                  // 3
        _frame(path: 'e.jpg', isKeyframe: true, crop: cropC),  // 4
      ]);

      // Between index 0 and 2, midpoint is 1 → t = 0.5.
      final seg1Mid = interpolateCrop(burst, 1)!;
      expect(seg1Mid.x, closeTo(0.25, 1e-10)); // (0+0.5)/2
      expect(seg1Mid.y, closeTo(0.25, 1e-10));

      // Between index 2 and 4, midpoint is 3 → t = 0.5.
      final seg2Mid = interpolateCrop(burst, 3)!;
      expect(seg2Mid.x, closeTo(0.75, 1e-10)); // (0.5+1.0)/2
      expect(seg2Mid.y, closeTo(0.75, 1e-10));
    });
  });
}
