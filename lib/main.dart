import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/crypto/crypto_service.dart';
import 'core/utils/clipboard_utils.dart';
import 'core/utils/logger.dart';
import 'core/providers/close_behavior_provider.dart';
import 'core/router/app_router.dart';
import 'core/tray_service.dart';
import 'l10n/app_localizations.dart';
import 'features/database/providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await fileLogOutput.init();
  CryptoService.initialize();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(900, 680),
      minimumSize: Size(400, 300),
      center: true,
      title: 'KeeVault',
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setPreventClose(true);
    });
  }

  runApp(const ProviderScope(child: KeeVaultAppWrapper()));
}

class KeeVaultAppWrapper extends ConsumerStatefulWidget {
  const KeeVaultAppWrapper({super.key});

  @override
  ConsumerState<KeeVaultAppWrapper> createState() => _KeeVaultAppWrapperState();
}

class _KeeVaultAppWrapperState extends ConsumerState<KeeVaultAppWrapper>
    with WindowListener {
  bool _trayInitialized = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initTray();
      });
    }
  }

  Future<void> _initTray() async {
    final navContext = rootNavigatorKey.currentContext;
    final l10n = navContext != null ? AppLocalizations.of(navContext) : null;
    try {
      await TrayService().init(
        showLabel: l10n?.showMainWindow ?? 'Show Main Window',
        exitLabel: l10n?.exit ?? 'Exit',
        onShowWindow: _showWindow,
        onExitApp: _exitApp,
      );
      _trayInitialized = true;
    } catch (e) {
      log.w('Tray init failed, close will exit app', error: e);
      _trayInitialized = false;
    }
  }

  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> _persistDirtyDatabase() async {
    final db = ref.read(databaseProvider).valueOrNull;
    final isDirty = ref.read(isDirtyProvider);
    if (db == null || !isDirty) return;

    try {
      // Local disk write happens first inside save(); the timeout mainly
      // bounds slow cloud sync retries so app exit isn't blocked for ~45s.
      final success = await ref
          .read(databaseProvider.notifier)
          .save()
          .timeout(const Duration(seconds: 20));
      if (!success) {
        log.w(
          'Database save before app exit completed locally, but cloud sync reported a conflict.',
        );
      }
    } on TimeoutException {
      log.w('Save before app exit timed out; local save may have completed.');
    } catch (e, st) {
      log.e('Failed to save database before app exit', error: e, stackTrace: st);
    }
  }

  Future<void> _exitApp() async {
    try {
      await _persistDirtyDatabase();
      await clearClipboardIfCopied();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {}
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final behavior = ref.read(closeBehaviorProvider);
    if (behavior == CloseBehavior.exit) {
      await _persistDirtyDatabase();
      await clearClipboardIfCopied();
      await windowManager.setPreventClose(false);
      await windowManager.close();
      return;
    }
    if (behavior == CloseBehavior.minimizeToTray) {
      if (_trayInitialized) {
        await windowManager.hide();
      } else {
        await _persistDirtyDatabase();
        await clearClipboardIfCopied();
        await windowManager.setPreventClose(false);
        await windowManager.close();
      }
      return;
    }
    await _showCloseDialog();
  }

  Future<void> _showCloseDialog() async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null) {
      await windowManager.hide();
      return;
    }
    final l10n = AppLocalizations.of(navContext);
    bool remember = false;

    final result = await showDialog<bool>(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bodyStyle = theme.textTheme.bodyMedium;
        final labelStyle = theme.textTheme.labelLarge;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(l10n?.close ?? 'Close', style: theme.textTheme.titleLarge),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n?.closeWindowMessage ?? 'What would you like to do?', style: bodyStyle),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(l10n?.minimize ?? 'Minimize', style: labelStyle),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(l10n?.exit ?? 'Exit', style: labelStyle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: remember,
                        onChanged: (v) => setDialogState(() => remember = v ?? false),
                      ),
                      Flexible(
                        child: Text(l10n?.rememberChoice ?? 'Remember my choice', style: bodyStyle),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      if (remember) {
        await ref.read(closeBehaviorProvider.notifier).setCloseBehavior(CloseBehavior.exit);
      }
      await _persistDirtyDatabase();
      await clearClipboardIfCopied();
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } else {
      if (remember) {
        await ref.read(closeBehaviorProvider.notifier).setCloseBehavior(CloseBehavior.minimizeToTray);
      }
      if (_trayInitialized) {
        await windowManager.hide();
      } else {
        await _persistDirtyDatabase();
        await clearClipboardIfCopied();
        await windowManager.setPreventClose(false);
        await windowManager.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const KeeVaultApp();
  }
}
