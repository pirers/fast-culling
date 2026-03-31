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

    final outputDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose export folder',
    );
    if (!mounted || outputDir == null) return;

    setState(() {
      _exporting = true;
      _exportProgress = null;
    });

    final service = const FfmpegServiceImpl();
    final available = await service.isAvailable();
    if (!mounted) return;

    if (!available) {
      setState(() => _exporting = false);
      messenger.showSnackBar(
        const SnackBar(
            content: Text(
                'FFmpeg not found on PATH. Install ffmpeg to export videos.')),
      );
      return;
    }

    final result = await service.exportBurst(
      burst: burst,
      outputDirectory: outputDir,
      fps: burst.defaultFps,
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
          Expanded(
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
        width: 160,
        margin: const EdgeInsets.only(right: 8, bottom: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: frame.isKeyframe ? Colors.amber : Colors.grey.shade300,
            width: frame.isKeyframe ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
                child: Opacity(
                  opacity: frame.included ? 1.0 : 0.45,
                  child: Image.file(
                    File(frame.photo.absolutePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    cacheWidth: 320,
                    errorBuilder: (ctx, e, st) => Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child:
                          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
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
