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
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: ClayDecoration.card(brightness: brightness, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
