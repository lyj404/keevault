import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../providers/database_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentFiles = ref.watch(recentFilesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'KeePass 兼容的密码管理器',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 44),

                    // Primary action – clay button
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
                      child: FilledButton.icon(
                        onPressed: () => _openFile(context, ref),
                        icon: const Icon(Icons.folder_open_rounded, size: 20),
                        label: const Text('打开本地数据库'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Secondary action
                    OutlinedButton.icon(
                      onPressed: () => context.push('/create'),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('创建新数据库'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Download from WebDAV
                    OutlinedButton.icon(
                      onPressed: () => _downloadFromWebDav(context, ref),
                      icon: const Icon(Icons.cloud_download_rounded, size: 20),
                      label: const Text('打开云端数据库'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),

                    // Recent files
                    recentFiles.when(
                      data: (files) {
                        if (files.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '最近打开',
                                    style: textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${files.length}',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...files.map((path) => _RecentFileTile(
                                    filePath: path,
                                    onTap: () => context.push('/unlock?path=${Uri.encodeComponent(path)}'),
                                    onRemove: () async {
                                      await ref.read(recentFilesServiceProvider).removeRecentFile(path);
                                      ref.invalidate(recentFilesProvider);
                                    },
                                  )),
                            ],
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Settings icon - top right
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: ClayDecoration.iconContainer(
                    brightness: Theme.of(context).brightness,
                    radius: 12,
                  ),
                  child: Icon(Icons.settings_rounded, size: 20, color: colorScheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['kdbx'],
    );
    if (result != null && result.files.single.path != null) {
      if (context.mounted) {
        context.push('/unlock?path=${Uri.encodeComponent(result.files.single.path!)}');
      }
    }
  }

  Future<void> _downloadFromWebDav(BuildContext context, WidgetRef ref) async {
    final config = await ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) {
      if (context.mounted) {
        _showErrorDialog(context, '请先在设置中配置 WebDAV');
      }
      return;
    }
    if (!context.mounted) return;
    final syncService = ref.read(syncServiceProvider);
    final exists = await syncService.remoteFileExists(config);
    if (!exists) {
      if (context.mounted) {
        _showErrorDialog(context, '云端还没有数据库，请先在本地创建并保存后同步');
      }
      return;
    }
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SyncLoadingDialog(message: '正在从云端下载...'),
    );
    try {
      final localPath = await syncService.downloadToLocal(config);
      if (context.mounted) {
        Navigator.of(context).pop();
        context.push('/unlock?path=${Uri.encodeComponent(localPath)}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        _showErrorDialog(context, '下载失败: $e');
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('取消'),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/settings');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }
}

class _SyncLoadingDialog extends StatelessWidget {
  final String message;
  const _SyncLoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _RecentFileTile extends StatelessWidget {
  final String filePath;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentFileTile({required this.filePath, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = filePath.split(Platform.pathSeparator).last;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: ClayDecoration.card(
          brightness: brightness,
          radius: 16,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: ClayDecoration.iconContainer(
                      brightness: brightness,
                      radius: 12,
                    ),
                    child: Icon(Icons.description_rounded, size: 18, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          filePath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded, size: 15, color: colorScheme.outline),
                      ),
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
}
