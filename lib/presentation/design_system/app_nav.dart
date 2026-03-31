import 'package:flutter/material.dart';

/// A navigation destination descriptor.
class AppNavDestination {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;

  const AppNavDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
}

/// Light-adaptive navigation wrapper.
///
/// Renders a [NavigationRail] for desktop layout. Can be swapped for a native
/// sidebar later without changing screen code.
class AppNav extends StatelessWidget {
  final List<AppNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) => NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        destinations: [
          for (final d in destinations)
            NavigationRailDestination(
              icon: Icon(d.icon),
              selectedIcon:
                  d.selectedIcon != null ? Icon(d.selectedIcon) : null,
              label: Text(d.label),
            ),
        ],
      );
}
