import 'package:fast_culling/presentation/design_system/app_nav.dart';
import 'package:fast_culling/presentation/design_system/app_scaffold.dart';
import 'package:fast_culling/presentation/screens/burst/burst_screen.dart';
import 'package:fast_culling/presentation/screens/sftp/sftp_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Home screen with side navigation for the two main modules.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    AppNavDestination(
      label: 'SFTP',
      icon: Icons.upload,
      selectedIcon: Icons.upload_outlined,
    ),
    AppNavDestination(
      label: 'Bursts',
      icon: Icons.burst_mode,
      selectedIcon: Icons.burst_mode_outlined,
    ),
  ];

  static const _screens = [
    SftpScreen(),
    BurstScreen(),
  ];

  @override
  Widget build(BuildContext context) => AppScaffold(
        body: Row(
          children: [
            AppNav(
              destinations: _destinations,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _screens[_selectedIndex]),
          ],
        ),
      );
}
