import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../providers/database_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _autoOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoOpen());
  }

  Future<void> _tryAutoOpen() async {
    if (_autoOpened) return;
    final lastFile = await ref.read(recentFilesServiceProvider).getLastOpenedFile();
    if (lastFile == null || !mounted) return;

    final localFile = File(lastFile.path);
    final exists = await localFile.exists();

    if (!lastFile.isCloud) {
      if (exists && mounted) {
        _autoOpened = true;
        context.push('/unlock?path=${Uri.encodeComponent(lastFile.path)}');
      }
      return;
    }

    if (!exists) return;
    _autoOpened = true;
    final config = await ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) {
      if (mounted) {
        ref.read(openedFromCloudProvider.notifier).state = true;
        context.push('/unlock?path=${Uri.encodeComponent(lastFile.path)}&cloud=true');
      }
      return;
    }
    final syncService = ref.read(syncServiceProvider);
    final remoteInfo = await syncService.getRemoteFileInfo(config);
    if (!mounted) return;
    if (remoteInfo != null) {
      final lastETag = lastFile.lastSyncedETag;
      if (lastETag != null && remoteInfo.eTag != null && lastETag == remoteInfo.eTag) {
        ref.read(openedFromCloudProvider.notifier).state = true;
        context.push('/unlock?path=${Uri.encodeComponent(lastFile.path)}&cloud=true');
        return;
      }
      final l10n = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _SyncLoadingDialog(message: l10n.syncingCloudDatabase),
      );
      try {
        final localPath = await syncService.downloadToLocal(config);
        if (remoteInfo.eTag != null) {
          final recentService = ref.read(recentFilesServiceProvider);
          await recentService.addRecentFile(localPath, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: remoteInfo.eTag);
          await recentService.setLastOpenedFile(localPath, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: remoteInfo.eTag);
        }
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ref.read(openedFromCloudProvider.notifier).state = true;
          context.push('/unlock?path=${Uri.encodeComponent(localPath)}&cloud=true');
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ref.read(openedFromCloudProvider.notifier).state = true;
          context.push('/unlock?path=${Uri.encodeComponent(lastFile.path)}&cloud=true');
        }
      }
    } else {
      ref.read(openedFromCloudProvider.notifier).state = true;
      context.push('/unlock?path=${Uri.encodeComponent(lastFile.path)}&cloud=true');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentFiles = ref.watch(recentFilesProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;

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
                      l10n.appSubtitle,
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
                        onPressed: () => _openFile(context),
                        icon: const Icon(Icons.folder_open_rounded, size: 20),
                        label: Text(l10n.openLocalDatabase),
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
                      label: Text(l10n.createNewDatabase),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Download from WebDAV
                    OutlinedButton.icon(
                      onPressed: () => _downloadFromWebDav(context),
                      icon: const Icon(Icons.cloud_download_rounded, size: 20),
                      label: Text(l10n.openCloudDatabase),
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
                                    l10n.recentOpened,
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
                              ...files.map((file) => _RecentFileTile(
                                    recentFile: file,
                                    onTap: () {
                                      if (file.isCloud) {
                                        ref.read(openedFromCloudProvider.notifier).state = true;
                                        _downloadFromWebDav(context, recentFile: file);
                                      } else {
                                        context.push('/unlock?path=${Uri.encodeComponent(file.path)}');
                                      }
                                    },
                                    onRemove: () async {
                                      await ref.read(recentFilesServiceProvider).removeRecentFile(file.path);
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

  Future<void> _openFile(BuildContext context) async {
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

  Future<void> _downloadFromWebDav(BuildContext context, {RecentFile? recentFile}) async {
    final l10n = AppLocalizations.of(context)!;
    final config = await ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) {
      if (context.mounted) {
        _showErrorDialog(context, l10n.pleaseConfigureWebDAV);
      }
      return;
    }
    if (!context.mounted) return;
    final syncService = ref.read(syncServiceProvider);
    final remoteInfo = await syncService.getRemoteFileInfo(config);
    if (remoteInfo == null) {
      if (context.mounted) {
        _showErrorDialog(context, l10n.cloudNoDatabaseCreateFirst);
      }
      return;
    }

    // eTag check: skip download if local cache is already up-to-date
    final cachedFile = recentFile;
    if (cachedFile != null && cachedFile.isCloud) {
      final localFile = File(cachedFile.path);
      final exists = await localFile.exists();
      if (exists && cachedFile.lastSyncedETag != null && remoteInfo.eTag != null &&
          cachedFile.lastSyncedETag == remoteInfo.eTag) {
        // Local cache is current, open directly
        ref.read(openedFromCloudProvider.notifier).state = true;
        if (context.mounted) {
          context.push('/unlock?path=${Uri.encodeComponent(cachedFile.path)}&cloud=true');
        }
        return;
      }
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SyncLoadingDialog(message: l10n.downloadingFromCloud),
    );
    try {
      final localPath = await syncService.downloadToLocal(config);
      if (remoteInfo.eTag != null) {
        final recentService = ref.read(recentFilesServiceProvider);
        await recentService.addRecentFile(localPath, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: remoteInfo.eTag);
        await recentService.setLastOpenedFile(localPath, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: remoteInfo.eTag);
      }
      if (context.mounted) {
        Navigator.of(context).pop();
        ref.read(openedFromCloudProvider.notifier).state = true;
        context.push('/unlock?path=${Uri.encodeComponent(localPath)}&cloud=true');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        final msg = e.toString().replaceFirst('Exception: ', '');
        final translated = msg == 'remote_database_not_exist'
            ? l10n.remoteDatabaseNotExist
            : l10n.downloadFailed(msg);
        _showErrorDialog(context, translated);
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(l10n.cancel),
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
            child: Text(l10n.goToSettings),
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
    final colorScheme = Theme.of(context).colorScheme;
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
            Text(message, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _RecentFileTile extends StatelessWidget {
  final RecentFile recentFile;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentFileTile({required this.recentFile, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = recentFile.path.split(Platform.pathSeparator).last;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context)!;

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
                    child: Icon(
                      recentFile.isCloud ? Icons.cloud_rounded : Icons.description_rounded,
                      size: 18,
                      color: recentFile.isCloud ? Colors.teal : colorScheme.primary,
                    ),
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
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recentFile.isCloud
                              ? '${l10n.cloudPrefix} · ${recentFile.remotePath ?? recentFile.path}'
                              : recentFile.path,
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
