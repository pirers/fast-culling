import 'package:flutter/material.dart';

/// Light-adaptive dialog wrapper. Forwards to [AlertDialog].
class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: actions,
      );

  /// Convenience method to show this dialog.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget> actions = const [],
  }) =>
      showDialog<T>(
        context: context,
        builder: (_) => AppDialog(
          title: title,
          content: content,
          actions: actions,
        ),
      );
}
