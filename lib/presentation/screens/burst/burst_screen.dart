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
                        : 'No bursts detected.\nTry increasing the gap slider above.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (state.photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Current gap: ${(state.thresholdMs / 1000).round()} s  •  '
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
                  _BurstCard(burst: state.bursts[i]),
            ),
    );
  }
}

class _BurstCard extends StatelessWidget {
  final Burst burst;
  const _BurstCard({required this.burst});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              Navigator.of(context).pushNamed('/burst/detail', arguments: burst.id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRect(
                    child: Image.file(
                      File(burst.frames.first.photo.absolutePath),
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
                  '${burst.frames.length} frames',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  burst.id,
                  style: Theme.of(context).textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
}
