import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/database_provider.dart';

class CreateDatabaseScreen extends ConsumerStatefulWidget {
  const CreateDatabaseScreen({super.key});

  @override
  ConsumerState<CreateDatabaseScreen> createState() => _CreateDatabaseScreenState();
}

class _CreateDatabaseScreenState extends ConsumerState<CreateDatabaseScreen> {
  late TextEditingController _nameController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _savePath;
  bool _initialized = false;
  Uint8List? _keyData;
  String? _keyFileName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _nameController = TextEditingController(text: AppLocalizations.of(context)!.myDatabase);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

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
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createDatabase)),
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
                  // Clay icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ClayColors.primary.withValues(alpha: 0.15),
                          ClayColors.secondary.withValues(alpha: 0.1),
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
                    child: Icon(Icons.add_rounded, size: 34, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.databaseName,
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterName : null,
                  ),
                  const SizedBox(height: 14),
                  PasswordTextField(
                    controller: _passwordController,
                    labelText: l10n.masterPassword,
                    showStrengthIndicator: true,
                    validator: (v) => (v == null || v.isEmpty) ? l10n.pleaseEnterPassword : null,
                  ),
                  const SizedBox(height: 14),
                  PasswordTextField(
                    controller: _confirmController,
                    labelText: l10n.confirmPassword,
                    validator: (v) => v != _passwordController.text ? l10n.passwordsNotMatch : null,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickSaveLocation,
                    icon: Icon(_savePath != null ? Icons.check_circle_outline_rounded : Icons.save_as_rounded, size: 18),
                    label: Text(
                      _savePath == null
                          ? l10n.selectSaveLocation
                          : _savePath!.split('/').last.split('\\').last,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: _savePath != null ? colorScheme.primary : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildKeyFilePicker(l10n, colorScheme),
                  const SizedBox(height: 24),
                  dbState.isLoading
                      ? SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: colorScheme.primary),
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
                            onPressed: _savePath != null ? _create : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: Text(l10n.create),
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

  Future<void> _pickSaveLocation() async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveDatabase,
        fileName: '${_nameController.text}${AppConstants.kdbxExtension}',
        type: FileType.custom,
        allowedExtensions: ['kdbx'],
      );
      if (result != null) {
        setState(() => _savePath = result);
      }
    } catch (e) {
      log.e('Failed to pick save location', error: e);
    }
  }

  void _create() {
    if (!_formKey.currentState!.validate() || _savePath == null) return;
    ref.read(databaseProvider.notifier).createDatabase(
          _nameController.text,
          _passwordController.text,
          _savePath!,
          keyData: _keyData,
        );
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
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          );
  }

  Future<void> _pickKeyFile() async {
    try {
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
    } catch (e) {
      log.e('Failed to pick key file', error: e);
    }
  }
}
