import 'dart:async';
import 'dart:io';

import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/burst_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Burst detection overview screen — shows detected bursts in a grid.
class BurstScreen extends ConsumerWidget {
  const BurstScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(burstProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Burst Detection'),
        actions: [
          AppButton(
            label: 'Select Folder',
            variant: AppButtonVariant.secondary,
            onPressed: state.isScanning
                ? null
                : () async {
                    final path =
                        await FilePicker.platform.getDirectoryPath();
                    if (path != null) {
                      ref
                          .read(burstProvider.notifier)
                          .scanDirectory(path);
                    }
                  },
          ),
          const SizedBox(width: 16),
          // Threshold slider — controls the maximum gap between consecutive
          // shots that still counts as the same burst.
          Tooltip(
            message:
                'Max time gap between consecutive shots to be grouped as one burst.\n'
                'Increase this if your shots are spread over several seconds.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 4),
                const Text('Gap:'),
                const SizedBox(width: 4),
                SizedBox(
                  width: 160,
                  child: Slider(
                    min: 1,
                    max: 30,
                    divisions: 29,
                    value: (state.thresholdMs / 1000).clamp(1.0, 30.0),
                    label: '${(state.thresholdMs / 1000).round()} s',
                    onChanged: (v) {
                      ref
                          .read(burstProvider.notifier)
                          .setThreshold((v * 1000).round());
                    },
                  ),
                ),
                Text('${(state.thresholdMs / 1000).round()} s',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Minimum-frames slider — bursts below this frame count are hidden.
          Tooltip(
            message:
                'Minimum number of frames for a group to be shown as a burst.\n'
                'Increase this to hide short sequences.',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.photo_library_outlined, size: 18),
                const SizedBox(width: 4),
                const Text('Min frames:'),
                const SizedBox(width: 4),
          // Min frames: 2–50 covers every practical burst size (2-frame panning
          // shots up to 50-frame high-speed sequences).  Extend if needed.
                SizedBox(
                  width: 120,
                  child: Slider(
                    min: 2,
                    max: 50,
                    divisions: 48,
                    value: state.minFrames.clamp(2, 50).toDouble(),
                    label: '${state.minFrames}',
                    onChanged: (v) {
                      ref
                          .read(burstProvider.notifier)
                          .setMinFrames(v.round());
                    },
                  ),
                ),
                Text('${state.minFrames}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Detect Bursts',
            onPressed: state.photos.isEmpty
                ? null
                : () => ref.read(burstProvider.notifier).detectBursts(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isScanning
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Scanning… ${state.photos.length} file(s) found'),
                ],
              ),
            )
          : state.bursts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.burst_mode,
                      size: 64, color: Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    state.photos.isEmpty
                        ? 'Select a folder to begin.'
                        : 'No bursts detected.\nTry increasing the gap or decreasing the minimum frames.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (state.photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Gap: ${(state.thresholdMs / 1000).round()} s  •  '
                      'Min frames: ${state.minFrames}  •  '
                      '${state.photos.length} photo(s) scanned',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: state.bursts.length,
              itemBuilder: (context, i) =>
                  _AnimatedBurstCard(burst: state.bursts[i]),
            ),
    );
  }
}

/// A burst card that animates through all frames in the burst at ~800 ms per frame.
class _AnimatedBurstCard extends StatefulWidget {
  final Burst burst;
  const _AnimatedBurstCard({required this.burst});

  @override
  State<_AnimatedBurstCard> createState() => _AnimatedBurstCardState();
}

class _AnimatedBurstCardState extends State<_AnimatedBurstCard> {
  int _frameIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_AnimatedBurstCard old) {
    super.didUpdateWidget(old);
    if (old.burst.id != widget.burst.id ||
        old.burst.frames.length != widget.burst.frames.length) {
      _frameIndex = 0;
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.burst.frames.length > 1) {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
        if (mounted) {
          setState(() =>
              _frameIndex = (_frameIndex + 1) % widget.burst.frames.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.burst.frames[_frameIndex];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .pushNamed('/burst/detail', arguments: widget.burst.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRect(
                  child: Image.file(
                    File(frame.photo.absolutePath),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    cacheWidth: 480,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.burst.frames.length} frames',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                widget.burst.id,
                style: Theme.of(context).textTheme.labelSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
