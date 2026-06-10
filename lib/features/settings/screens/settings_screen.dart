import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/toast.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('同步设置')),
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
                              const Text('WebDAV 同步', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text('保存时自动同步到云端',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
                            decoration: const InputDecoration(
                              labelText: '服务器地址',
                              hintText: 'https://example.com/dav/',
                              helperText: 'WebDAV 服务地址，不含文件名',
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? '请输入服务器地址' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _userController,
                            decoration: const InputDecoration(labelText: '用户名'),
                            validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
                          ),
                          const SizedBox(height: 12),
                          PasswordTextField(
                            controller: _passwordController,
                            labelText: '密码',
                            validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pathController,
                            decoration: const InputDecoration(
                              labelText: '远程路径（可选）',
                              hintText: '例如 /keepass，留空则保存在根目录',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _filenameController,
                            decoration: const InputDecoration(labelText: '文件名', hintText: 'database.kdbx'),
                            validator: (v) => (v == null || v.isEmpty) ? '请输入文件名' : null,
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
                            label: Text(_testing ? '测试中...' : '测试连接'),
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
                            Text(
                              _connectionOk! ? '连接成功' : '连接失败，请检查配置',
                              style: TextStyle(
                                fontSize: 13,
                                color: _connectionOk! ? ClayColors.secondary : ClayColors.error,
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
                        child: const Text('保存'),
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
    });
    final config = WebDavConfig(
      serverUrl: _urlController.text.trim(),
      username: _userController.text.trim(),
      password: _passwordController.text,
      remotePath: _pathController.text.trim(),
      remoteFilename: _filenameController.text.trim(),
    );
    final ok = await ref.read(syncServiceProvider).testConnection(config);
    if (mounted) setState(() {
      _testing = false;
      _connectionOk = ok;
    });
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
    if (mounted) {
      showToast(context, '已保存');
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
