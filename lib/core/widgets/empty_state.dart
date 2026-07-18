import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? ClayColors.primaryContainerDark
                  : colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
              boxShadow: ClayDecoration.outerShadow(brightness),
            ),
            child: Icon(icon, size: 36, color: colorScheme.primary),
          ),
          const SizedBox(height: ClayLayout.space16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
