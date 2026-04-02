import 'package:flutter/material.dart';

enum AppProgressStyle { linear, circular }

/// Light-adaptive progress indicator wrapper.
class AppProgress extends StatelessWidget {
  /// Value in 0..1, or null for indeterminate.
  final double? value;
  final AppProgressStyle style;
  final String? label;

  const AppProgress({
    super.key,
    this.value,
    this.style = AppProgressStyle.linear,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = style == AppProgressStyle.linear
        ? LinearProgressIndicator(value: value)
        : CircularProgressIndicator(value: value);

    if (label == null) return indicator;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(height: 4),
        Text(label!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
