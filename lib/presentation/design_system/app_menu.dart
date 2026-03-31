import 'package:flutter/material.dart';

/// A simple menu item descriptor.
class AppMenuItem {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const AppMenuItem({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });
}

/// Light-adaptive menu wrapper.
///
/// Renders a [PopupMenuButton] for M0; can be swapped for a native menu later.
class AppMenu extends StatelessWidget {
  final List<AppMenuItem> items;
  final Widget child;

  const AppMenu({
    super.key,
    required this.items,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => PopupMenuButton<int>(
        itemBuilder: (_) => [
          for (var i = 0; i < items.length; i++)
            PopupMenuItem<int>(
              value: i,
              enabled: items[i].enabled,
              child: Text(items[i].label),
            ),
        ],
        onSelected: (i) => items[i].onTap(),
        child: child,
      );
}
