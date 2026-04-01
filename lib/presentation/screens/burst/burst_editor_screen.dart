import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:fast_culling/domain/algorithms/crop_interpolator.dart';
import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/domain/entities/crop_rect.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/burst_provider.dart';
import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Burst editor screen — include/exclude frames, set keyframes, manage crops.
///
/// Edits are staged locally; they are committed to the provider only when the
/// user taps **Save**.  Navigating back without saving discards all changes.
class BurstEditorScreen extends ConsumerStatefulWidget {
  final String burstId;
  const BurstEditorScreen({super.key, required this.burstId});

  @override
  ConsumerState<BurstEditorScreen> createState() => _BurstEditorScreenState();
}

class _BurstEditorScreenState extends ConsumerState<BurstEditorScreen> {
  /// Local working copy — mutations here do NOT touch provider state.
  Burst? _localBurst;

  /// Currently selected frame index for the crop editor panel.
  int? _selectedFrameIndex;

  @override
  void initState() {
    super.initState();
    // One-time read to seed the local copy; changes are staged here until Save.
    final source = ref
        .read(burstProvider)
        .burstById(widget.burstId);
    if (source != null) {
      _localBurst = Burst(
        id: source.id,
        aspectRatio: source.aspectRatio,
        defaultFps: source.defaultFps,
        defaultResolution: List<int>.from(source.defaultResolution),
        frames: source.frames
            .map((f) => BurstFrame(
                  photo: f.photo,
                  included: f.included,
                  isKeyframe: f.isKeyframe,
                  crop: f.crop,
                ))
            .toList(),
      );
    }
  }

  void _save() {
    if (_localBurst != null) {
      ref.read(burstProvider.notifier).updateBurst(_localBurst!);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final burst = _localBurst;

    if (burst == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Burst Editor')),
        body: const Center(child: Text('Burst not found.')),
      );
    }

    final hasAnyCrop = burst.frames.any((f) => f.crop != null);
    final selectedFrame =
        _selectedFrameIndex != null ? burst.frames[_selectedFrameIndex!] : null;

    return AppScaffold(
      appBar: AppBar(
        title: Text('Edit: ${burst.id}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Aspect ratio:'),
                const SizedBox(width: 8),
                DropdownButton<AspectRatio?>(
                  value: burst.aspectRatio,
                  // Disabled once a keyframe crop is defined — ratio is then fixed.
                  items: hasAnyCrop
                      ? null
                      : [
                          const DropdownMenuItem(
                              value: null, child: Text('— none —')),
                          for (final ar in AspectRatio.values)
                            DropdownMenuItem(
                              value: ar,
                              child: Text(ar.toLabel()),
                            ),
                        ],
                  onChanged: hasAnyCrop
                      ? null
                      : (ar) => setState(() => burst.aspectRatio = ar),
                ),
                if (hasAnyCrop && burst.aspectRatio != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Chip(
                      label: Text(burst.aspectRatio!.toLabel()),
                      avatar: const Icon(Icons.lock_outline, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          AppButton(label: 'Save', onPressed: _save),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // ── Left: frame list ──────────────────────────────────────────────
          SizedBox(
            width: 280,
            child: ListView.builder(
              itemCount: burst.frames.length,
              itemBuilder: (context, i) => _EditorFrameTile(
                frame: burst.frames[i],
                index: i,
                isSelected: _selectedFrameIndex == i,
                onTap: () => setState(() => _selectedFrameIndex = i),
                onIncludedChanged: (value) {
                  setState(() => burst.frames[i].included = value);
                },
                onKeyframeChanged: (value) {
                  setState(() {
                    burst.frames[i].isKeyframe = value;
                    // Removing keyframe status also clears any explicit crop so
                    // the frame no longer anchors the interpolation.
                    if (!value) burst.frames[i].crop = null;
                  });
                },
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // ── Right: crop editor ────────────────────────────────────────────
          Expanded(
            child: selectedFrame != null
                ? _CropEditorPanel(
                    key: ValueKey(_selectedFrameIndex),
                    frame: selectedFrame,
                    frameIndex: _selectedFrameIndex!,
                    burst: burst,
                    targetAspectRatio: burst.aspectRatio,
                    onCropChanged: (crop) {
                      setState(() {
                        burst.frames[_selectedFrameIndex!].crop = crop;
                        // Non-null crop auto-promotes to keyframe; null clears it.
                        burst.frames[_selectedFrameIndex!].isKeyframe =
                            crop != null;
                      });
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_outlined,
                            size: 48, color: Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          'Tap a frame to edit its crop.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Frames marked ★ are keyframes — their crops are\n'
                          'interpolated across the burst.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Frame tile ───────────────────────────────────────────────────────────────

class _EditorFrameTile extends StatelessWidget {
  final BurstFrame frame;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<bool> onIncludedChanged;
  final ValueChanged<bool> onKeyframeChanged;

  const _EditorFrameTile({
    required this.frame,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.onIncludedChanged,
    required this.onKeyframeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ColoredBox(
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
            : Colors.transparent,
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 72,
              height: 72,
              margin: const EdgeInsets.all(8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: frame.isKeyframe
                      ? Colors.amber
                      : (isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300),
                  width: frame.isKeyframe || isSelected ? 2 : 1,
                ),
              ),
              child: Opacity(
                opacity: frame.included ? 1.0 : 0.45,
                child: Image.file(
                  File(frame.photo.absolutePath),
                  fit: BoxFit.cover,
                  cacheWidth: 144,
                  errorBuilder: (ctx, e, st) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, size: 24),
                  ),
                ),
              ),
            ),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${index + 1}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    frame.photo.relativePath.split('/').last,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (frame.crop != null)
                    Text(
                      'crop set',
                      style: TextStyle(
                          fontSize: 10, color: Colors.green.shade700),
                    ),
                ],
              ),
            ),
            // Controls
            Checkbox(
              value: frame.included,
              onChanged: (v) => onIncludedChanged(v ?? frame.included),
            ),
            IconButton(
              icon: Icon(
                frame.isKeyframe ? Icons.star : Icons.star_outline,
                color: frame.isKeyframe ? Colors.amber : null,
              ),
              tooltip: 'Toggle keyframe',
              onPressed: () => onKeyframeChanged(!frame.isKeyframe),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Crop editor panel ────────────────────────────────────────────────────────

/// Which part of the crop rect is being dragged.
enum _DragTarget { none, move, topLeft, topRight, bottomLeft, bottomRight }

/// Interactive crop-rectangle editor.
///
/// Displays the frame's image (via [ui.Image] for pixel-accurate layout) and
/// overlays a draggable crop rectangle with corner handles.  The crop is stored
/// in normalised coordinates (0–1 relative to the image dimensions).
class _CropEditorPanel extends StatefulWidget {
  final BurstFrame frame;
  final int frameIndex;
  final Burst burst;
  final AspectRatio? targetAspectRatio;
  final ValueChanged<CropRect?> onCropChanged;

  const _CropEditorPanel({
    super.key,
    required this.frame,
    required this.frameIndex,
    required this.burst,
    required this.targetAspectRatio,
    required this.onCropChanged,
  });

  @override
  State<_CropEditorPanel> createState() => _CropEditorPanelState();
}

class _CropEditorPanelState extends State<_CropEditorPanel> {
  ui.Image? _image;
  CropRect? _crop;

  /// Cached image rect within the widget, recomputed each build.
  Rect _imageRect = Rect.zero;

  // Drag state
  _DragTarget _dragTarget = _DragTarget.none;
  Offset? _dragStart;
  CropRect? _cropAtDragStart;

  static const double _handleRadius = 7.0;
  static const double _handleHitRadius = 18.0;

  @override
  void initState() {
    super.initState();
    _crop = _initialCrop();
    _loadImage();
  }

  /// Returns the initial crop: prefer frame crop → interpolated → aspect-ratio
  /// default → full image.
  CropRect _initialCrop() {
    if (widget.frame.crop != null) return widget.frame.crop!;
    final interp = interpolateCrop(widget.burst, widget.frameIndex);
    if (interp != null) return interp;
    if (widget.targetAspectRatio != null) {
      return _defaultCropForAspectRatio(widget.targetAspectRatio!);
    }
    return const CropRect(x: 0, y: 0, w: 1, h: 1);
  }

  CropRect _defaultCropForAspectRatio(AspectRatio ar) {
    final ratio = _arValue(ar); // width / height
    // Assume the photo is landscape (w > h). Adjust if needed.
    if (ratio >= 1.0) {
      // Wider or square target — crop height.
      final h = 1 / ratio;
      return CropRect(x: 0, y: (1 - h) / 2, w: 1, h: h.clamp(0.0, 1.0));
    } else {
      // Taller target — crop width.
      final w = ratio;
      return CropRect(x: (1 - w) / 2, y: 0, w: w.clamp(0.0, 1.0), h: 1);
    }
  }

  /// Snaps [crop] to [ar] by adjusting height from the current width,
  /// keeping the crop centre stable.
  CropRect _snapToAspectRatio(CropRect crop, AspectRatio ar) {
    if (_image == null) return _defaultCropForAspectRatio(ar);
    final arValue = _arValue(ar);
    final newH =
        (crop.w * _image!.width / (_image!.height * arValue)).clamp(0.0, 1.0);
    final cy = crop.y + crop.h / 2;
    final newY = (cy - newH / 2).clamp(0.0, 1.0 - newH);
    return CropRect(x: crop.x, y: newY, w: crop.w, h: newH);
  }

  double _arValue(AspectRatio ar) {
    switch (ar) {
      case AspectRatio.ratio1x1:
        return 1.0;
      case AspectRatio.ratio4x5:
        return 4 / 5;
      case AspectRatio.ratio9x16:
        return 9 / 16;
      case AspectRatio.ratio16x9:
        return 16 / 9;
      case AspectRatio.ratio3x2:
        return 3 / 2;
      case AspectRatio.ratio2x3:
        return 2 / 3;
    }
  }

  Future<void> _loadImage() async {
    try {
      final bytes =
          await File(widget.frame.photo.absolutePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _image = frame.image);
    } catch (_) {}
  }

  /// Computes the rect (in widget local coordinates) occupied by the image
  /// when rendered with BoxFit.contain inside [widgetSize].
  Rect _computeImageRect(Size widgetSize) {
    if (_image == null) return Rect.zero;
    final imgW = _image!.width.toDouble();
    final imgH = _image!.height.toDouble();
    final scale = min(widgetSize.width / imgW, widgetSize.height / imgH);
    final displayW = imgW * scale;
    final displayH = imgH * scale;
    return Rect.fromLTWH(
      (widgetSize.width - displayW) / 2,
      (widgetSize.height - displayH) / 2,
      displayW,
      displayH,
    );
  }

  /// Converts a normalised [CropRect] to widget-local pixel coordinates.
  Rect _cropToPixels(CropRect c) => Rect.fromLTWH(
        _imageRect.left + c.x * _imageRect.width,
        _imageRect.top + c.y * _imageRect.height,
        c.w * _imageRect.width,
        c.h * _imageRect.height,
      );

  _DragTarget _hitTest(Offset point, Rect cropPx) {
    bool near(Offset a) => (point - a).distance <= _handleHitRadius;
    if (near(cropPx.topLeft)) return _DragTarget.topLeft;
    if (near(cropPx.topRight)) return _DragTarget.topRight;
    if (near(cropPx.bottomLeft)) return _DragTarget.bottomLeft;
    if (near(cropPx.bottomRight)) return _DragTarget.bottomRight;
    if (cropPx.contains(point)) return _DragTarget.move;
    return _DragTarget.none;
  }

  void _onPanStart(DragStartDetails d) {
    if (_crop == null || _imageRect.isEmpty) return;
    final cropPx = _cropToPixels(_crop!);
    _dragTarget = _hitTest(d.localPosition, cropPx);
    if (_dragTarget != _DragTarget.none) {
      _dragStart = d.localPosition;
      _cropAtDragStart = _crop;
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragTarget == _DragTarget.none ||
        _dragStart == null ||
        _cropAtDragStart == null) return;

    final delta = d.localPosition - _dragStart!;
    final dx = delta.dx / _imageRect.width;
    final dy = delta.dy / _imageRect.height;
    final s = _cropAtDragStart!;
    const minSize = 0.05;

    // When an aspect ratio is locked, corner drags maintain the ratio.
    // The ratio in normalised coordinates: h_norm = w_norm * imgW / (imgH * arValue)
    final ar = widget.targetAspectRatio != null && _image != null
        ? _arValue(widget.targetAspectRatio!)
        : null;

    // Helper: given normalised width, return the matching normalised height.
    double constrainedH(double w) {
      if (ar == null || _image == null) return w;
      return w * _image!.width / (_image!.height * ar);
    }

    final CropRect updated;
    switch (_dragTarget) {
      case _DragTarget.move:
        updated = CropRect(
          x: (s.x + dx).clamp(0.0, 1.0 - s.w),
          y: (s.y + dy).clamp(0.0, 1.0 - s.h),
          w: s.w,
          h: s.h,
        );
      case _DragTarget.topLeft:
        if (ar != null) {
          // Right and bottom fixed; width drives height.
          final newX = (s.x + dx).clamp(0.0, s.x + s.w - minSize);
          final newW = (s.x + s.w - newX).clamp(minSize, 1.0);
          final newH = constrainedH(newW).clamp(minSize, 1.0);
          final newY = (s.y + s.h - newH).clamp(0.0, 1.0);
          updated = CropRect(x: newX, y: newY, w: newW, h: newH);
        } else {
          final newX = (s.x + dx).clamp(0.0, s.x + s.w - minSize);
          final newY = (s.y + dy).clamp(0.0, s.y + s.h - minSize);
          updated = CropRect(
            x: newX,
            y: newY,
            w: s.w - (newX - s.x),
            h: s.h - (newY - s.y),
          );
        }
      case _DragTarget.topRight:
        if (ar != null) {
          // Left and bottom fixed; width drives height.
          final newW = (s.w + dx).clamp(minSize, 1.0 - s.x);
          final newH = constrainedH(newW).clamp(minSize, 1.0);
          final newY = (s.y + s.h - newH).clamp(0.0, 1.0);
          updated = CropRect(x: s.x, y: newY, w: newW, h: newH);
        } else {
          final newY = (s.y + dy).clamp(0.0, s.y + s.h - minSize);
          updated = CropRect(
            x: s.x,
            y: newY,
            w: (s.w + dx).clamp(minSize, 1.0 - s.x),
            h: s.h - (newY - s.y),
          );
        }
      case _DragTarget.bottomLeft:
        if (ar != null) {
          // Right and top fixed; width drives height.
          final newX = (s.x + dx).clamp(0.0, s.x + s.w - minSize);
          final newW = (s.x + s.w - newX).clamp(minSize, 1.0);
          final newH = constrainedH(newW).clamp(minSize, 1.0 - s.y);
          updated = CropRect(x: newX, y: s.y, w: newW, h: newH);
        } else {
          final newX = (s.x + dx).clamp(0.0, s.x + s.w - minSize);
          updated = CropRect(
            x: newX,
            y: s.y,
            w: s.w - (newX - s.x),
            h: (s.h + dy).clamp(minSize, 1.0 - s.y),
          );
        }
      case _DragTarget.bottomRight:
        if (ar != null) {
          // Left and top fixed; width drives height.
          final newW = (s.w + dx).clamp(minSize, 1.0 - s.x);
          final newH = constrainedH(newW).clamp(minSize, 1.0 - s.y);
          updated = CropRect(x: s.x, y: s.y, w: newW, h: newH);
        } else {
          updated = CropRect(
            x: s.x,
            y: s.y,
            w: (s.w + dx).clamp(minSize, 1.0 - s.x),
            h: (s.h + dy).clamp(minSize, 1.0 - s.y),
          );
        }
      case _DragTarget.none:
        return;
    }

    setState(() => _crop = updated);
    widget.onCropChanged(updated);
  }

  void _onPanEnd(DragEndDetails _) {
    _dragTarget = _DragTarget.none;
    _dragStart = null;
    _cropAtDragStart = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Text(
                'Frame #${widget.frameIndex + 1}'
                '${widget.frame.isKeyframe ? '  ★ Keyframe' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              // Only show "Reset crop" when this frame has an explicit crop
              // saved (not just an interpolated preview).
              if (widget.frame.crop != null)
                TextButton.icon(
                  icon: const Icon(Icons.crop_free, size: 16),
                  label: const Text('Reset crop'),
                  onPressed: () {
                    // Notify parent to clear crop + keyframe on the frame.
                    widget.onCropChanged(null);
                    // Re-derive the displayed crop from the now-cleared frame
                    // (will show interpolated or aspect-ratio default if available).
                    setState(() => _crop = _initialCrop());
                  },
                ),
              if (widget.targetAspectRatio != null)
                TextButton.icon(
                  icon: const Icon(Icons.aspect_ratio, size: 16),
                  label: Text(
                      'Snap to ${widget.targetAspectRatio!.toLabel()}'),
                  onPressed: () {
                    // Snap current crop to the locked aspect ratio,
                    // maintaining the crop centre.
                    final c = _snapToAspectRatio(
                        _crop ?? const CropRect(x: 0, y: 0, w: 1, h: 1),
                        widget.targetAspectRatio!);
                    setState(() => _crop = c);
                    widget.onCropChanged(c);
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Image + crop overlay
        Expanded(
          child: _image == null
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Update the cached image rect used by gesture handlers.
                    _imageRect = _computeImageRect(
                        Size(constraints.maxWidth, constraints.maxHeight));
                    return GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _CropOverlayPainter(
                          image: _image!,
                          imageRect: _imageRect,
                          crop: _crop,
                          handleRadius: _handleRadius,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Crop overlay painter ─────────────────────────────────────────────────────

class _CropOverlayPainter extends CustomPainter {
  final ui.Image image;
  final Rect imageRect;
  final CropRect? crop;
  final double handleRadius;

  _CropOverlayPainter({
    required this.image,
    required this.imageRect,
    required this.crop,
    required this.handleRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image, filling exactly the computed imageRect.
    paintImage(
      canvas: canvas,
      rect: imageRect,
      image: image,
      fit: BoxFit.fill,
    );

    if (crop == null) return;

    final cropPx = Rect.fromLTWH(
      imageRect.left + crop!.x * imageRect.width,
      imageRect.top + crop!.y * imageRect.height,
      crop!.w * imageRect.width,
      crop!.h * imageRect.height,
    );

    // Dim the area outside the crop with a semi-transparent overlay.
    final dimPaint = Paint()..color = Colors.black54;
    canvas.drawRect(
        Rect.fromLTRB(
            imageRect.left, imageRect.top, imageRect.right, cropPx.top),
        dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(
            imageRect.left, cropPx.bottom, imageRect.right, imageRect.bottom),
        dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(
            imageRect.left, cropPx.top, cropPx.left, cropPx.bottom),
        dimPaint);
    canvas.drawRect(
        Rect.fromLTRB(
            cropPx.right, cropPx.top, imageRect.right, cropPx.bottom),
        dimPaint);

    // Crop border
    canvas.drawRect(
        cropPx,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    // Rule-of-thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 0.5;
    for (var i = 1; i <= 2; i++) {
      final x = cropPx.left + cropPx.width * i / 3;
      final y = cropPx.top + cropPx.height * i / 3;
      canvas.drawLine(Offset(x, cropPx.top), Offset(x, cropPx.bottom), gridPaint);
      canvas.drawLine(
          Offset(cropPx.left, y), Offset(cropPx.right, y), gridPaint);
    }

    // Corner handles
    final handleFill = Paint()..color = Colors.white;
    final handleStroke = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final corner in [
      cropPx.topLeft,
      cropPx.topRight,
      cropPx.bottomLeft,
      cropPx.bottomRight,
    ]) {
      canvas.drawCircle(corner, handleRadius, handleFill);
      canvas.drawCircle(corner, handleRadius, handleStroke);
    }
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) =>
      old.image != image ||
      old.imageRect != imageRect ||
      old.crop != crop;
}
