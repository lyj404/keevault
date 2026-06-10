import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/password_generator.dart';
import '../utils/clipboard_utils.dart';
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

    return AlertDialog(
      title: const Text('生成密码'),
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
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  _password,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 0.5),
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
                        showToast(context, '已复制密码');
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('复制'),
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
                      label: const Text('重新生成'),
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
                  Text('密码长度', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  SizedBox(
                    width: 56,
                    height: 32,
                    child: TextField(
                      controller: _lengthCtrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                          setState(() => _length = n);
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
                  });
                },
                onChangeEnd: (_) => _regenerate(),
              ),
              const SizedBox(height: 8),

              // Character types
              Text('字符类型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              _buildToggle(
                value: _upper,
                title: '大写字母 A-Z',
                onChanged: (v) => setState(() { _upper = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _lower,
                title: '小写字母 a-z',
                onChanged: (v) => setState(() { _lower = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _digits,
                title: '数字 0-9',
                onChanged: (v) => setState(() { _digits = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _symbols,
                title: '符号 !@#\$%^&*',
                onChanged: (v) => setState(() { _symbols = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _hyphen,
                title: '减号 -',
                onChanged: (v) => setState(() { _hyphen = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _underscore,
                title: '下划线 _',
                onChanged: (v) => setState(() { _underscore = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _parentheses,
                title: '括号 ()',
                onChanged: (v) => setState(() { _parentheses = v; _regenerate(); }),
              ),
              _buildToggle(
                value: _space,
                title: '空格',
                onChanged: (v) => setState(() { _space = v; _regenerate(); }),
              ),

              // Custom symbols
              const SizedBox(height: 20),
              Text('自定义符号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: _customSymbolsCtrl,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: '输入额外要包含的符号',
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
                  _customSymbols = v;
                  _regenerate();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _password),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('使用此密码'),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required bool value,
    required String title,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 36,
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
