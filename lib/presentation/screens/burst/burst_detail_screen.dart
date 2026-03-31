import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/burst_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Detail view for a single burst — shows frame strip and basic info.
class BurstDetailScreen extends ConsumerWidget {
  final String burstId;
  const BurstDetailScreen({super.key, required this.burstId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(burstProvider);
    final burst = state.bursts.cast<Burst?>().firstWhere(
          (b) => b?.id == burstId,
          orElse: () => null,
        );

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
          AppButton(
            label: 'Edit',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context)
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
              child: Container(
                color: frame.included ? Colors.grey.shade200 : Colors.grey.shade400,
                alignment: Alignment.center,
                child: Icon(
                  frame.included ? Icons.photo : Icons.photo_outlined,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Text('#${index + 1}',
                      style: Theme.of(context).textTheme.labelSmall),
                  if (frame.isKeyframe)
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                ],
              ),
            ),
          ],
        ),
      );
}
