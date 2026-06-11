import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/toast.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../data/webdav_config.dart';
import '../providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController();
  final _filenameController = TextEditingController(text: 'database.kdbx');
  bool _enabled = false;
  bool _testing = false;
  bool? _connectionOk;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ref.read(webDavSettingsServiceProvider).getConfig();
    if (config != null && mounted) {
      setState(() {
        _enabled = config.enabled;
        _urlController.text = config.serverUrl;
        _userController.text = config.username;
        _passwordController.text = config.password;
        _pathController.text = config.remotePath;
        _filenameController.text = config.remoteFilename;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.syncSettings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Language switcher card
                  _SectionCard(
                    brightness: brightness,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: ClayDecoration.iconContainer(brightness: brightness),
                          child: Icon(Icons.language_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.language, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        DropdownButton<String>(
                          value: currentLocale?.languageCode ?? 'system',
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(value: 'system', child: Text(l10n.followSystem)),
                            const DropdownMenuItem(value: 'zh', child: Text('中文')),
                            const DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            if (v == 'system') {
                              ref.read(localeProvider.notifier).setLocale(null);
                            } else {
                              ref.read(localeProvider.notifier).setLocale(Locale(v));
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Theme switcher card
                  _SectionCard(
                    brightness: brightness,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: ClayDecoration.iconContainer(brightness: brightness),
                          child: Icon(
                            currentThemeMode == ThemeMode.dark
                                ? Icons.dark_mode_rounded
                                : currentThemeMode == ThemeMode.light
                                    ? Icons.light_mode_rounded
                                    : Icons.brightness_auto_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.theme, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colorScheme.onSurface)),
                            ],
                          ),
                        ),
                        DropdownButton<ThemeMode>(
                          value: currentThemeMode,
                          underline: const SizedBox.shrink(),
                          items: [
                            DropdownMenuItem(value: ThemeMode.system, child: Text(l10n.followSystem)),
                            DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.lightTheme)),
                            DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.darkTheme)),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(themeModeProvider.notifier).setThemeMode(v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Enable toggle card
                  _SectionCard(
                    brightness: brightness,
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: ClayDecoration.iconContainer(brightness: brightness),
                          child: Icon(Icons.cloud_upload_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.webdavSync, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colorScheme.onSurface)),
                              Text(l10n.autoSyncOnSave,
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),

                  if (_enabled) ...[
                    const SizedBox(height: 16),
                    // Config card
                    _SectionCard(
                      brightness: brightness,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              labelText: l10n.serverAddress,
                              hintText: l10n.serverAddressHint,
                              helperText: l10n.serverAddressHelper,
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterServerAddress : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _userController,
                            decoration: InputDecoration(labelText: l10n.username),
                            validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterUsername : null,
                          ),
                          const SizedBox(height: 12),
                          PasswordTextField(
                            controller: _passwordController,
                            labelText: l10n.password,
                            showPrefixIcon: false,
                            validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterPassword : null,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.appPasswordHelper,
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pathController,
                            decoration: InputDecoration(
                              labelText: l10n.remotePathOptional,
                              hintText: l10n.remotePathHint,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _filenameController,
                            decoration: InputDecoration(labelText: l10n.filename, hintText: 'database.kdbx'),
                            validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterName : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Test connection
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testConnection,
                            icon: _testing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.wifi_find_rounded, size: 18),
                            label: Text(_testing ? l10n.testing : l10n.testConnection),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_connectionOk != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _connectionOk!
                              ? ClayColors.secondary.withValues(alpha: 0.1)
                              : ClayColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _connectionOk! ? Icons.check_circle_rounded : Icons.error_rounded,
                              size: 18,
                              color: _connectionOk! ? ClayColors.secondary : ClayColors.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _connectionOk! ? l10n.connectionSuccess : (_connectionError ?? l10n.connectionFailed),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _connectionOk! ? ClayColors.secondary : ClayColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Save button
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
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _testing = true;
      _connectionOk = null;
      _connectionError = null;
    });
    final config = WebDavConfig(
      serverUrl: _urlController.text.trim(),
      username: _userController.text.trim(),
      password: _passwordController.text,
      remotePath: _pathController.text.trim(),
      remoteFilename: _filenameController.text.trim(),
    );
    final errorKey = await ref.read(syncServiceProvider).testConnection(config);
    if (mounted) setState(() {
      _testing = false;
      _connectionOk = errorKey == null;
      _connectionError = _translateError(errorKey);
    });
  }

  String? _translateError(String? errorKey) {
    if (errorKey == null) return null;
    final l10n = AppLocalizations.of(context)!;
    if (errorKey == 'auth_failed') return l10n.authFailedCheckCredentials;
    if (errorKey == 'network_failed') return l10n.networkFailedCheckServer;
    if (errorKey.startsWith('path_not_accessible:')) {
      final path = errorKey.substring('path_not_accessible:'.length);
      return l10n.serverConnectedPathNotAccessible(path);
    }
    if (errorKey.startsWith('connection_failed:')) {
      final msg = errorKey.substring('connection_failed:'.length);
      return l10n.connectionFailedMsg(msg);
    }
    return errorKey;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final config = WebDavConfig(
      serverUrl: _urlController.text.trim(),
      username: _userController.text.trim(),
      password: _passwordController.text,
      remotePath: _pathController.text.trim(),
      remoteFilename: _filenameController.text.trim(),
      enabled: _enabled,
    );
    await ref.read(webDavSettingsServiceProvider).saveConfig(config);
    ref.invalidate(webDavConfigProvider);
    final l10n = AppLocalizations.of(context)!;
    if (mounted) {
      showToast(context, l10n.saved);
      Navigator.of(context).pop();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final Brightness brightness;
  final Widget child;

  const _SectionCard({required this.brightness, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ClayDecoration.card(brightness: brightness, radius: 18),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}
