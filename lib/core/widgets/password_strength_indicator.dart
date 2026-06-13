import 'package:flutter/material.dart';
import '../utils/password_strength.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final level = evaluatePasswordStrength(password);
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final label = isZh ? level.labelZh : level.labelEn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level.fraction,
            backgroundColor: level.color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(level.color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: level.color),
        ),
      ],
    );
  }
}
