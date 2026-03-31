import 'package:flutter/material.dart';

/// Light-adaptive scaffold wrapper.
///
/// Forwards to [Scaffold] in Material mode. Swap the implementation here to
/// adopt native platform scaffolding without touching screen code.
class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.drawer,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: appBar,
        drawer: drawer,
        floatingActionButton: floatingActionButton,
        body: body,
      );
}
