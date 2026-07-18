import 'package:flutter/material.dart';
import '../utils/password_generator.dart';
import '../utils/clipboard_utils.dart';
import '../../l10n/app_localizations.dart';
import 'toast.dart';

/// Shows a password generator dialog and returns the generated password, or null if cancelled.
Future<String?> showPasswordGeneratorDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => const _PasswordGeneratorDialog(),
  );
}

class _PasswordGeneratorDialog extends StatefulWidget {
  const _PasswordGeneratorDialog();

  @override
  State<_PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<_PasswordGeneratorDialog> {
  int _length = 15;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = true;
  bool _hyphen = false;
  bool _space = false;
  bool _underscore = true;
  bool _parentheses = false;
  String _customSymbols = '';
  late String _password;

  final _lengthCtrl = TextEditingController(text: '15');
  final _customSymbolsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _password = _generate();
  }

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _customSymbolsCtrl.dispose();
    super.dispose();
  }

  String _generate() {
    return PasswordGenerator.generate(
      length: _length,
      useUppercase: _upper,
      useLowercase: _lower,
      useDigits: _digits,
      useSymbols: _symbols,
      useHyphen: _hyphen,
      useSpace: _space,
      useUnderscore: _underscore,
      useParentheses: _parentheses,
      customSymbols: _customSymbols,
    );
  }

  void _regenerate() {
    setState(() => _password = _generate());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.generatePasswordTitle),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview – clay style
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? 0.28
                            : 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  _password,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 0.5, color: colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 10),
              // Copy + Regenerate
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        copyToClipboardWithAutoClear(_password);
                        showToast(context, l10n.copiedPassword);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(l10n.copied),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _regenerate,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.regenerate),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Length
              Row(
                children: [
                  Text(l10n.passwordLength, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  SizedBox(
                    width: 56,
                    height: 32,
                    child: TextField(
                      controller: _lengthCtrl,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerLow,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 4 && n <= 128) {
                          setState(() {
                            _length = n;
                            _password = _generate();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              Slider(
                value: _length.toDouble(),
                min: 4,
                max: 128,
                divisions: 124,
                onChanged: (v) {
                  final n = v.round();
                  setState(() {
                    _length = n;
                    _lengthCtrl.text = '$n';
                    _password = _generate();
                  });
                },
              ),
              const SizedBox(height: 8),

              // Character types
              Text(l10n.characterTypes, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              _buildToggle(
                value: _upper,
                title: l10n.uppercaseAZ,
                onChanged: (v) => setState(() { _upper = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _lower,
                title: l10n.lowercaseaz,
                onChanged: (v) => setState(() { _lower = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _digits,
                title: l10n.digits09,
                onChanged: (v) => setState(() { _digits = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _symbols,
                title: l10n.symbols,
                onChanged: (v) => setState(() { _symbols = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _hyphen,
                title: l10n.hyphen,
                onChanged: (v) => setState(() { _hyphen = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _underscore,
                title: l10n.underscore,
                onChanged: (v) => setState(() { _underscore = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _parentheses,
                title: l10n.parentheses,
                onChanged: (v) => setState(() { _parentheses = v; _password = _generate(); }),
              ),
              _buildToggle(
                value: _space,
                title: l10n.space,
                onChanged: (v) => setState(() { _space = v; _password = _generate(); }),
              ),

              // Custom symbols
              const SizedBox(height: 20),
              Text(l10n.customSymbols, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: _customSymbolsCtrl,
                style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: l10n.customSymbolsHint,
                  hintStyle: TextStyle(fontSize: 12, color: colorScheme.outline),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                ),
                onChanged: (v) {
                  setState(() { _customSymbols = v; _password = _generate(); });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _password),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(l10n.useThisPassword),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
