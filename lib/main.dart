import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/providers/close_behavior_provider.dart';
import 'core/router/app_router.dart';
import 'core/tray_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initTray();
      });
    }
  }

  Future<void> _initTray() async {
    final navContext = rootNavigatorKey.currentContext;
    final l10n = navContext != null ? AppLocalizations.of(navContext) : null;
    await TrayService().init(
      showLabel: l10n?.showMainWindow ?? 'Show Main Window',
      exitLabel: l10n?.exit ?? 'Exit',
      onShowWindow: _showWindow,
      onExitApp: _exitApp,
    );
  }

  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  void _exitApp() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
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
      await windowManager.setPreventClose(false);
      await windowManager.close();
      return;
    }
    if (behavior == CloseBehavior.minimizeToTray) {
      await windowManager.hide();
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
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } else {
      if (remember) {
        await ref.read(closeBehaviorProvider.notifier).setCloseBehavior(CloseBehavior.minimizeToTray);
      }
      await windowManager.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const KeeVaultApp();
  }
}
