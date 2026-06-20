import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/providers/biometric_provider.dart';
import '../../../core/services/biometric_service.dart';
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
  Uint8List? _keyData;
  String? _keyFileName;

  bool _biometricTriggered = false;

  @override
  void initState() {
    super.initState();
    ref.read(databaseProvider.notifier).preloadFile(widget.filePath);
    final bioEnabled = ref.read(biometricEnabledProvider);
    debugPrint('UnlockScreen: initState, biometricEnabled=$bioEnabled');
    // Auto-trigger biometric auth when provider loads
    ref.listen<bool>(biometricEnabledProvider, (prev, next) {
      debugPrint('UnlockScreen: biometricEnabledProvider changed $prev -> $next');
      if (next && !_biometricTriggered) {
        _biometricTriggered = true;
        debugPrint('UnlockScreen: triggering biometric from listen');
        WidgetsBinding.instance.addPostFrameCallback((_) => _biometricUnlock());
      }
    });
    // Also check if already loaded
    if (bioEnabled && !_biometricTriggered) {
      _biometricTriggered = true;
      debugPrint('UnlockScreen: triggering biometric from immediate check');
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometricUnlock());
    }
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
      if (next.isLoading) {
        setState(() => _error = null);
      } else if (next.hasValue) {
        if (next.value != null) context.go('/explorer');
      } else if (next.hasError) {
        setState(() => _error = _friendlyError(next.error!, l10n));
      }
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
                  const SizedBox(height: 14),
                  _buildKeyFilePicker(l10n, colorScheme),
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
                      : Column(
                          children: [
                            Container(
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
                            if (Platform.isAndroid && ref.watch(biometricEnabledProvider)) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _biometricUnlock,
                                icon: const Icon(Icons.fingerprint_rounded, size: 24),
                                label: Text(l10n.unlockWithBiometric),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                              ),
                            ],
                          ],
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

    // Store password if biometric is enabled
    if (Platform.isAndroid && ref.read(biometricEnabledProvider)) {
      BiometricService().storePassword(widget.filePath, _passwordController.text);
    }

    ref.read(databaseProvider.notifier).openFile(widget.filePath, _passwordController.text, isCloud: widget.isCloud, syncedETag: widget.syncedETag, keyData: _keyData);
  }

  Future<void> _biometricUnlock() async {
    final l10n = AppLocalizations.of(context)!;
    final biometricService = BiometricService();

    final authenticated = await biometricService.authenticate(l10n.authenticateToUnlock);
    if (!authenticated) return;

    final storedPassword = await biometricService.getStoredPassword(widget.filePath);
    if (storedPassword == null) {
      // No stored password, need to unlock with password first
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noStoredPassword)),
        );
      }
      return;
    }

    setState(() => _error = null);
    ref.read(databaseProvider.notifier).openFile(widget.filePath, storedPassword, isCloud: widget.isCloud, syncedETag: widget.syncedETag, keyData: _keyData);
  }

  Widget _buildKeyFilePicker(AppLocalizations l10n, ColorScheme colorScheme) {
    return _keyData != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.key_rounded, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _keyFileName ?? l10n.keyFileSelected,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                  onPressed: () => setState(() {
                    _keyData = null;
                    _keyFileName = null;
                  }),
                  tooltip: l10n.removeKeyFile,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          )
        : OutlinedButton.icon(
            onPressed: _pickKeyFile,
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: Text(l10n.selectKeyFile),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
  }

  Future<void> _pickKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _keyData = file.bytes;
          _keyFileName = file.name;
        });
      }
    }
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
