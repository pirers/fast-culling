import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/crop_rect.dart';

/// Returns the interpolated [CropRect] for [frameIndex] within [burst].
///
/// Interpolation rules:
/// - No keyframes → returns null.
/// - Before the first keyframe (or equal to it) → first keyframe's crop.
/// - After the last keyframe (or equal to it) → last keyframe's crop.
/// - Between two keyframes → linear interpolation of x, y, w, h.
CropRect? interpolateCrop(Burst burst, int frameIndex) {
  // Collect keyframes that have a crop defined, preserving frame order.
  final keyframes = <({int index, CropRect crop})>[];
  for (var i = 0; i < burst.frames.length; i++) {
    final frame = burst.frames[i];
    if (frame.isKeyframe && frame.crop != null) {
      keyframes.add((index: i, crop: frame.crop!));
    }
  }

  if (keyframes.isEmpty) return null;

  // Before or at the first keyframe.
  if (frameIndex <= keyframes.first.index) {
    return keyframes.first.crop;
  }

  // After or at the last keyframe.
  if (frameIndex >= keyframes.last.index) {
    return keyframes.last.crop;
  }

  // Find the surrounding keyframe pair.
  for (var k = 0; k < keyframes.length - 1; k++) {
    final prev = keyframes[k];
    final next = keyframes[k + 1];

    if (frameIndex >= prev.index && frameIndex <= next.index) {
      final span = next.index - prev.index;
      // Avoid division by zero (adjacent keyframes).
      if (span == 0) return prev.crop;
      final t = (frameIndex - prev.index) / span;
      return _lerp(prev.crop, next.crop, t);
    }
  }

  // Fallback — should not reach here.
  return keyframes.last.crop;
}

CropRect _lerp(CropRect a, CropRect b, double t) => CropRect(
      x: a.x + (b.x - a.x) * t,
      y: a.y + (b.y - a.y) * t,
      w: a.w + (b.w - a.w) * t,
      h: a.h + (b.h - a.h) * t,
    );
