import 'package:fast_culling/presentation/providers/local_folder_provider.dart';
import 'package:flutter/material.dart';

class StarFilterBar extends StatelessWidget {
  final StarFilter current;
  final void Function(StarFilter) onChanged;

  const StarFilterBar({
    super.key,
    required this.current,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const filters = [
      (StarFilter.none, 'All'),
      (StarFilter.oneOrMore, '≥1★'),
      (StarFilter.twoOrMore, '≥2★'),
      (StarFilter.threeOrMore, '≥3★'),
      (StarFilter.fourOrMore, '≥4★'),
      (StarFilter.fiveOnly, '5★'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((entry) {
          final (filter, label) = entry;
          final selected = current == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => onChanged(filter),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}
