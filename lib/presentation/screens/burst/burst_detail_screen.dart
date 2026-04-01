import 'dart:io';

import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/burst_provider.dart';
import 'package:fast_culling/services/ffmpeg_service.dart';
import 'package:fast_culling/services/ffmpeg_service_impl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Detail view for a single burst — shows frame strip and basic info.
class BurstDetailScreen extends ConsumerStatefulWidget {
  final String burstId;
  const BurstDetailScreen({super.key, required this.burstId});

  @override
  ConsumerState<BurstDetailScreen> createState() => _BurstDetailScreenState();
}

class _BurstDetailScreenState extends ConsumerState<BurstDetailScreen> {
  bool _exporting = false;
  ExportProgress? _exportProgress;

  Future<void> _export(Burst burst) async {
    // Capture messenger before any async gap to satisfy use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);

    // ── Step 1: show export settings dialog ──────────────────────────────────
    final settings = await _showExportDialog(burst);
    if (settings == null || !mounted) return;

    // ── Step 2: pick output file path ─────────────────────────────────────────
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save burst as MP4',
      fileName: '${burst.id}.mp4',
      allowedExtensions: ['mp4'],
      type: FileType.custom,
    );
    if (!mounted || outputPath == null) return;

    setState(() {
      _exporting = true;
      _exportProgress = null;
    });

    // ── Step 3: check ffmpeg ──────────────────────────────────────────────────
    final service = const FfmpegServiceImpl();
    final available = await service.isAvailable();
    if (!mounted) return;

    if (!available) {
      setState(() => _exporting = false);
      messenger.showSnackBar(
        const SnackBar(
            content: Text('FFmpeg not found. '
                'Place the ffmpeg binary next to the app executable '
                'or install it system-wide — see the README for details.')),
      );
      return;
    }

    // ── Step 4: run export ────────────────────────────────────────────────────
    final result = await service.exportBurst(
      burst: burst,
      outputPath: outputPath,
      fps: settings.fps,
      imageDurationSeconds: settings.imageDurationSeconds,
      resolution: burst.defaultResolution,
      onProgress: (p) {
        if (mounted) setState(() => _exportProgress = p);
      },
    );

    if (!mounted) return;
    setState(() {
      _exporting = false;
      _exportProgress = null;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.success
            ? 'Exported to ${result.outputPath}'
            : 'Export failed: ${result.error}'),
      ),
    );
  }

  /// Shows the export-settings dialog and returns the chosen settings,
  /// or null if the user cancelled.
  Future<_ExportSettings?> _showExportDialog(Burst burst) {
    return showDialog<_ExportSettings>(
      context: context,
      builder: (ctx) => _ExportSettingsDialog(
        initialFps: burst.defaultFps,
        initialImageDurationSeconds: 1.0 / burst.defaultFps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(burstProvider);
    final burst = state.burstById(widget.burstId);

    if (burst == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Burst Detail')),
        body: const Center(child: Text('Burst not found.')),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text('Burst: ${burst.id}'),
        actions: [
          if (_exporting) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  _exportProgress != null
                      ? 'Exporting… ${(_exportProgress!.fraction * 100).round()}%'
                      : 'Exporting…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
          ] else ...[
            AppButton(
              label: 'Export MP4',
              onPressed: () => _export(burst),
            ),
            const SizedBox(width: 8),
          ],
          AppButton(
            label: 'Edit',
            variant: AppButtonVariant.secondary,
            onPressed: _exporting
                ? null
                : () => Navigator.of(context)
                    .pushNamed('/burst/editor', arguments: burst.id),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Frames: ${burst.frames.length}'),
                const SizedBox(width: 24),
                Text(
                  'FPS: ${burst.defaultFps}  |  '
                  'Resolution: ${burst.defaultResolution.join('×')}',
                ),
                if (burst.aspectRatio != null) ...[
                  const SizedBox(width: 24),
                  Text('Aspect: ${burst.aspectRatio!.toLabel()}'),
                ],
              ],
            ),
          ),
          // Fixed-height strip so tiles don't stretch to fill the remaining
          // screen height.  260 = 200 (image) + 8 (padding) + ~20 (labels)
          // + 32 (breathing room).
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: burst.frames.length,
              itemBuilder: (context, i) => _FrameTile(
                frame: burst.frames[i],
                index: i,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrameTile extends StatelessWidget {
  final BurstFrame frame;
  final int index;
  const _FrameTile({required this.frame, required this.index});

  @override
  Widget build(BuildContext context) => Container(
        // No fixed width — width is determined by the image's natural aspect ratio.
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: frame.isKeyframe ? Colors.amber : Colors.grey.shade300,
            width: frame.isKeyframe ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image at fixed height; width auto-scales to source aspect ratio.
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(3)),
              child: Opacity(
                opacity: frame.included ? 1.0 : 0.45,
                child: Image.file(
                  File(frame.photo.absolutePath),
                  height: 200,
                  fit: BoxFit.contain,
                  cacheWidth: 640,
                  errorBuilder: (ctx, e, st) => SizedBox(
                    width: 160,
                    height: 200,
                    child: Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image,
                          size: 40, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Text('#${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall),
                  if (!frame.included)
                    const Text('excluded',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                  if (frame.isKeyframe)
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─── Export settings ─────────────────────────────────────────────────────────

class _ExportSettings {
  final int fps;
  final double imageDurationSeconds;
  const _ExportSettings({required this.fps, required this.imageDurationSeconds});
}

/// Dialog that lets the user choose FPS and per-image duration before exporting.
class _ExportSettingsDialog extends StatefulWidget {
  final int initialFps;
  final double initialImageDurationSeconds;

  const _ExportSettingsDialog({
    required this.initialFps,
    required this.initialImageDurationSeconds,
  });

  @override
  State<_ExportSettingsDialog> createState() => _ExportSettingsDialogState();
}

class _ExportSettingsDialogState extends State<_ExportSettingsDialog> {
  late int _fps;
  late double _imageDuration; // seconds per image

  static const _fpsOptions = [12, 24, 25, 30, 50, 60];

  @override
  void initState() {
    super.initState();
    _fps = _fpsOptions.contains(widget.initialFps)
        ? widget.initialFps
        : _fpsOptions.first;
    // Clamp to slider range 0.1–5.0 s.
    _imageDuration = widget.initialImageDurationSeconds.clamp(0.1, 5.0);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export settings'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── FPS row ──────────────────────────────────────────────────────
            Text('Frame rate (FPS)',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _fpsOptions
                  .map((f) => ChoiceChip(
                        label: Text('$f'),
                        selected: _fps == f,
                        onSelected: (_) => setState(() => _fps = f),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            // ── Image duration row ───────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Duration per image',
                    style: Theme.of(context).textTheme.labelLarge),
                Text(
                  '${_imageDuration.toStringAsFixed(2)} s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Slider(
              // 0.1 s to 5.0 s in 0.1 s steps → 49 divisions
              min: 0.1,
              max: 5.0,
              divisions: 49,
              value: _imageDuration,
              label: '${_imageDuration.toStringAsFixed(2)} s',
              onChanged: (v) => setState(() => _imageDuration = v),
            ),
            const SizedBox(height: 4),
            Text(
              'Total video length ≈ '
              '${(_imageDuration * _fps).toStringAsFixed(0)} frames per image  •  '
              'Output: $_fps fps',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ExportSettings(fps: _fps, imageDurationSeconds: _imageDuration),
          ),
          child: const Text('Export'),
        ),
      ],
    );
  }
}
