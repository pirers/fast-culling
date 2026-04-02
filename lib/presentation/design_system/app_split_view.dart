import 'package:flutter/material.dart';

/// Light-adaptive split view wrapper.
///
/// Renders a [Row] with two [Expanded] children separated by a divider.
/// [leadingFlex] controls the relative width of the leading pane.
class AppSplitView extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  final int leadingFlex;
  final int trailingFlex;

  const AppSplitView({
    super.key,
    required this.leading,
    required this.trailing,
    this.leadingFlex = 1,
    this.trailingFlex = 2,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(flex: leadingFlex, child: leading),
          const VerticalDivider(width: 1),
          Expanded(flex: trailingFlex, child: trailing),
        ],
      );
}
