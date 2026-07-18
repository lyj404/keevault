import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable card container with clay styling, used across multiple screens.
class SectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const SectionCard({
    super.key,
    required this.children,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dense = ClayLayout.isDesktopPlatform(context);
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: ClayLayout.space12),
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: ClayLayout.space16,
            vertical: dense ? ClayLayout.space12 : 14,
          ),
      decoration: ClayDecoration.card(
        brightness: brightness,
        radius: ClayLayout.radiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
