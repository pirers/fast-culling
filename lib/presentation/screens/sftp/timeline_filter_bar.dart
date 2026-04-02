import 'package:fast_culling/presentation/providers/local_folder_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _formatDateTime(DateTime dt) {
  String pad(int n, [int w = 2]) => n.toString().padLeft(w, '0');
  return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}';
}

class TimelineFilterBar extends ConsumerWidget {
  const TimelineFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(localFolderProvider.notifier);
    final state = ref.watch(localFolderProvider);

    final min = notifier.minTimestamp;
    final max = notifier.maxTimestamp;

    if (min == null || max == null || min == max) return const SizedBox.shrink();

    final minMs = min.millisecondsSinceEpoch.toDouble();
    final maxMs = max.millisecondsSinceEpoch.toDouble();

    final fromMs = state.filterFrom?.millisecondsSinceEpoch.toDouble() ?? minMs;
    final toMs = state.filterTo?.millisecondsSinceEpoch.toDouble() ?? maxMs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(_formatDateTime(state.filterFrom ?? min),
                style: const TextStyle(fontSize: 11)),
            const Spacer(),
            Text(_formatDateTime(state.filterTo ?? max),
                style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 8),
            if (state.filterFrom != null || state.filterTo != null)
              TextButton(
                onPressed: notifier.clearDateRange,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Clear', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        RangeSlider(
          values: RangeValues(fromMs, toMs),
          min: minMs,
          max: maxMs,
          onChanged: (values) {
            notifier.setDateRange(
              DateTime.fromMillisecondsSinceEpoch(values.start.toInt()),
              DateTime.fromMillisecondsSinceEpoch(values.end.toInt()),
            );
          },
        ),
      ],
    );
  }
}
