/// Normalized crop rectangle; all values are in the range 0..1
/// relative to the image dimensions.
class CropRect {
  final double x;
  final double y;
  final double w;
  final double h;

  const CropRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory CropRect.fromJson(Map<String, dynamic> json) => CropRect(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        w: (json['w'] as num).toDouble(),
        h: (json['h'] as num).toDouble(),
      );

  @override
  String toString() => 'CropRect(x: $x, y: $y, w: $w, h: $h)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CropRect &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          w == other.w &&
          h == other.h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}
