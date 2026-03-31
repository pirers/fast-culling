import 'package:fast_culling/domain/entities/burst.dart';
import 'package:fast_culling/presentation/design_system/app_button.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/providers/burst_provider.dart';
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
                : () {
                    // Folder picker wired in M1.
                  },
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
      body: state.bursts.isEmpty
          ? Center(
              child: Text(
                state.photos.isEmpty
                    ? 'Select a folder to begin.'
                    : 'No bursts detected. Try adjusting the threshold.',
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
                  child: Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.burst_mode, size: 48),
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
