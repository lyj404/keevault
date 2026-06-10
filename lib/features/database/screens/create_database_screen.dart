import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_text_field.dart';
import '../providers/database_provider.dart';

class CreateDatabaseScreen extends ConsumerStatefulWidget {
  const CreateDatabaseScreen({super.key});

  @override
  ConsumerState<CreateDatabaseScreen> createState() => _CreateDatabaseScreenState();
}

class _CreateDatabaseScreenState extends ConsumerState<CreateDatabaseScreen> {
  final _nameController = TextEditingController(text: '我的数据库');
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _savePath;

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

    ref.listen(databaseProvider, (prev, next) {
      next.whenOrNull(
        data: (db) {
          if (db != null) context.go('/explorer');
        },
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('创建数据库')),
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
                    decoration: const InputDecoration(
                      labelText: '数据库名称',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? '请输入名称' : null,
                  ),
                  const SizedBox(height: 14),
                  PasswordTextField(
                    controller: _passwordController,
                    labelText: '主密码',
                    validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                  ),
                  const SizedBox(height: 14),
                  PasswordTextField(
                    controller: _confirmController,
                    labelText: '确认密码',
                    validator: (v) => v != _passwordController.text ? '两次密码不一致' : null,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _pickSaveLocation,
                    icon: Icon(_savePath != null ? Icons.check_circle_outline_rounded : Icons.save_as_rounded, size: 18),
                    label: Text(
                      _savePath == null
                          ? '选择保存位置'
                          : _savePath!.split('/').last.split('\\').last,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: _savePath != null ? colorScheme.primary : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
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
                            child: const Text('创建'),
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
    final result = await FilePicker.platform.saveFile(
      dialogTitle: '保存数据库',
      fileName: '${_nameController.text}${AppConstants.kdbxExtension}',
      type: FileType.custom,
      allowedExtensions: ['kdbx'],
    );
    if (result != null) {
      setState(() => _savePath = result);
    }
  }

  void _create() {
    if (!_formKey.currentState!.validate() || _savePath == null) return;
    ref.read(databaseProvider.notifier).createDatabase(
          _nameController.text,
          _passwordController.text,
          _savePath!,
        );
  }
}
