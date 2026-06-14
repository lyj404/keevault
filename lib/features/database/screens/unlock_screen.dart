import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/database_provider.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  final String filePath;
  final bool isCloud;
  final String? syncedETag;
  const UnlockScreen({super.key, required this.filePath, this.isCloud = false, this.syncedETag});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider.notifier).preloadFile(widget.filePath);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _fileName => widget.filePath.split(Platform.pathSeparator).last;

  @override
  Widget build(BuildContext context) {
    final dbState = ref.watch(databaseProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    ref.listen(databaseProvider, (prev, next) {
      next.whenOrNull(
        data: (db) {
          if (db != null) context.go('/explorer');
        },
        error: (e, _) {
          setState(() => _error = _friendlyError(e, l10n));
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.unlockDatabase),
        actions: [
          GestureDetector(
            onTap: () => context.push('/settings'),
            child: Container(
              width: 38,
              height: 38,
              decoration: ClayDecoration.iconContainer(
                brightness: Theme.of(context).brightness,
                radius: 12,
              ),
              child: Icon(Icons.settings_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clay lock icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ClayColors.primary.withValues(alpha: 0.15),
                          ClayColors.tertiary.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: ClayColors.primary.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.lock_rounded, size: 34, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _fileName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.isCloud ? l10n.cloudDatabase : widget.filePath,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  PasswordTextField(
                    controller: _passwordController,
                    labelText: l10n.masterPassword,
                    autofocus: true,
                    validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterPassword : null,
                    onFieldSubmitted: (_) => _unlock(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: ClayColors.error.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  dbState.isLoading
                      ? Column(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.decryptingFirstTimeSlow,
                              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: ClayColors.primary.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: FilledButton(
                            onPressed: _unlock,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: Text(l10n.unlock),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _unlock() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    ref.read(databaseProvider.notifier).openFile(widget.filePath, _passwordController.text, isCloud: widget.isCloud, syncedETag: widget.syncedETag);
  }

  String _friendlyError(Object e, AppLocalizations l10n) {
    final msg = e.toString();
    if (msg.contains('InvalidCredentials') || msg.contains('invalid key')) {
      return l10n.passwordError;
    }
    if (msg.contains('corrupt') || msg.contains('bad version')) {
      return l10n.fileFormatIncorrect;
    }
    return l10n.openFailed(msg);
  }
}
