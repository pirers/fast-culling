import 'package:fast_culling/domain/entities/crop_rect.dart';
import 'package:fast_culling/domain/entities/photo.dart';

enum AspectRatio {
  ratio1x1,
  ratio4x5,
  ratio9x16,
  ratio16x9,
  ratio3x2,
  ratio2x3;

  String toLabel() {
    switch (this) {
      case AspectRatio.ratio1x1:
        return '1:1';
      case AspectRatio.ratio4x5:
        return '4:5';
      case AspectRatio.ratio9x16:
        return '9:16';
      case AspectRatio.ratio16x9:
        return '16:9';
      case AspectRatio.ratio3x2:
        return '3:2';
      case AspectRatio.ratio2x3:
        return '2:3';
    }
  }

  static AspectRatio? fromLabel(String label) {
    for (final v in AspectRatio.values) {
      if (v.toLabel() == label) return v;
    }
    return null;
  }
}

class BurstFrame {
  final Photo photo;
  bool included;
  bool isKeyframe;
  CropRect? crop;

  BurstFrame({
    required this.photo,
    this.included = true,
    this.isKeyframe = false,
    this.crop,
  });
}

class Burst {
  final String id;
  List<BurstFrame> frames;
  AspectRatio? aspectRatio;
  int defaultFps;

  /// [width, height]
  List<int> defaultResolution;

  Burst({
    required this.id,
    required this.frames,
    this.aspectRatio,
    this.defaultFps = 30,
    this.defaultResolution = const [1920, 1080],
  });
}
