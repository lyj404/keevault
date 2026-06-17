import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../theme/app_theme.dart';
import 'password_text_field.dart';
import 'toast.dart';
import '../../l10n/app_localizations.dart';
import '../../features/database/providers/database_provider.dart';

/// Shows a dialog to change the master password of the currently open database.
Future<void> showChangePasswordDialog(BuildContext context) async {
  return showDialog(
    context: context,
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _oldPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: ClayDecoration.iconContainer(brightness: brightness),
            child: Icon(Icons.key_rounded, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Text(l10n.changeMasterPassword),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PasswordTextField(
                controller: _oldPasswordCtrl,
                labelText: l10n.currentPassword,
                autofocus: true,
                validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterCurrentPassword : null,
              ),
              const SizedBox(height: 14),
              PasswordTextField(
                controller: _newPasswordCtrl,
                labelText: l10n.newPassword,
                showStrengthIndicator: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.pleaseEnterNewPassword;
                  return null;
                },
              ),
              const SizedBox(height: 14),
              PasswordTextField(
                controller: _confirmCtrl,
                labelText: l10n.confirmNewPassword,
                validator: (v) {
                  if (v == null || v.isEmpty) return l10n.pleaseEnterPassword;
                  if (v != _newPasswordCtrl.text) return l10n.passwordsNotMatch;
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.confirm),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(databaseProvider.notifier).changePassword(
        _oldPasswordCtrl.text,
        _newPasswordCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        showToast(context, l10n.passwordChanged);
      }
    } on InvalidCredentialsError {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, l10n.passwordError, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, l10n.error(e.toString()), isError: true);
      }
    }
  }
}
