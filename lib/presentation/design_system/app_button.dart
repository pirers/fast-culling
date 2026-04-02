import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary }

/// Light-adaptive button wrapper.
///
/// [AppButtonVariant.primary] → [ElevatedButton]
/// [AppButtonVariant.secondary] → [TextButton]
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    switch (variant) {
      case AppButtonVariant.primary:
        return icon != null
            ? ElevatedButton.icon(
                onPressed: onPressed,
                icon: icon!,
                label: child,
              )
            : ElevatedButton(onPressed: onPressed, child: child);
      case AppButtonVariant.secondary:
        return icon != null
            ? TextButton.icon(
                onPressed: onPressed,
                icon: icon!,
                label: child,
              )
            : TextButton(onPressed: onPressed, child: child);
    }
  }
}
