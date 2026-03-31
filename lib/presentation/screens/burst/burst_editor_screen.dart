import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/burst_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Burst editor screen — include/exclude frames, set keyframes, manage crops.
class BurstEditorScreen extends ConsumerStatefulWidget {
  final String burstId;
  const BurstEditorScreen({super.key, required this.burstId});

  @override
  ConsumerState<BurstEditorScreen> createState() => _BurstEditorScreenState();
}

class _BurstEditorScreenState extends ConsumerState<BurstEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(burstProvider);
    final burst = state.bursts.cast<Burst?>().firstWhere(
          (b) => b?.id == widget.burstId,
          orElse: () => null,
        );

    if (burst == null) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Burst Editor')),
        body: const Center(child: Text('Burst not found.')),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        title: Text('Edit: ${burst.id}'),
        actions: [
          AppButton(
            label: 'Save',
            onPressed: () {
              ref.read(burstProvider.notifier).updateBurst(burst);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Aspect ratio:'),
                const SizedBox(width: 8),
                DropdownButton<AspectRatio?>(
                  value: burst.aspectRatio,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('— none —')),
                    for (final ar in AspectRatio.values)
                      DropdownMenuItem(
                        value: ar,
                        child: Text(ar.toLabel()),
                      ),
                  ],
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: burst.frames.length,
              itemBuilder: (context, i) => _EditorFrameTile(
                frame: burst.frames[i],
                onIncludedChanged: (value) {
                  setState(() => burst.frames[i].included = value);
                },
                onKeyframeChanged: (value) {
                  setState(() => burst.frames[i].isKeyframe = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorFrameTile extends StatelessWidget {
  final BurstFrame frame;
  final ValueChanged<bool> onIncludedChanged;
  final ValueChanged<bool> onKeyframeChanged;

  const _EditorFrameTile({
    required this.frame,
    required this.onIncludedChanged,
    required this.onKeyframeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        frame.included ? Icons.photo : Icons.photo_outlined,
        color: frame.included ? null : Colors.grey,
      ),
      title: Text(frame.photo.relativePath),
      subtitle: frame.isKeyframe ? const Text('Keyframe ★') : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );
  }
}
