import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/providers/auto_lock_provider.dart';
import 'core/providers/auto_save_provider.dart';
import 'core/providers/expiration_reminder_provider.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/privacy_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/utils/clipboard_utils.dart';
import 'features/database/providers/database_provider.dart';
import 'features/explorer/providers/explorer_provider.dart';
import 'features/sync/providers/sync_provider.dart';
import 'features/totp/data/totp_service.dart';
import 'l10n/app_localizations.dart';

class KeeVaultApp extends ConsumerStatefulWidget {
  const KeeVaultApp({super.key});

  @override
  ConsumerState<KeeVaultApp> createState() => _KeeVaultAppState();
}

class _KeeVaultAppState extends ConsumerState<KeeVaultApp>
    with WidgetsBindingObserver {
  final _focusNode = FocusNode();
  bool _backgroundPrivacyVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize notifications on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hideInBackground = ref.read(privacyProvider).hideInBackground;
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _backgroundPrivacyVisible = false);
      final db = ref.read(databaseProvider).valueOrNull;
      if (db != null) {
        ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db);
      }
    } else if (hideInBackground &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden)) {
      if (mounted) setState(() => _backgroundPrivacyVisible = true);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Reset auto-lock timer on any key activity (Bug #1 fix)
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      ref.read(autoLockProvider.notifier).resetTimer();
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrl) return KeyEventResult.ignored;

    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx == null) return KeyEventResult.ignored;

    final l10n = AppLocalizations.of(navCtx);

    // Ctrl+F and Ctrl+S are desktop-only shortcuts
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // Ctrl+F: navigate to search
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        GoRouter.of(navCtx).push('/search');
        return KeyEventResult.handled;
      }

      // Ctrl+S: save database
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        _saveDatabase(navCtx, l10n);
        return KeyEventResult.handled;
      }
    }

    // Copy shortcuts require an active entry
    final activeEntry = ref.read(activeEntryProvider);
    if (activeEntry == null) return KeyEventResult.ignored;

    String? message;
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      final username = activeEntry.fields['UserName']?.text ?? '';
      if (username.isNotEmpty) {
        copyToClipboardWithAutoClear(username);
        message = l10n!.copiedUsername;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final password = activeEntry.fields['Password']?.text ?? '';
      if (password.isNotEmpty) {
        copyToClipboardWithAutoClear(password);
        message = l10n!.copiedPassword;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyU) {
      final url = activeEntry.fields['URL']?.text ?? '';
      if (url.isNotEmpty) {
        copyToClipboardWithAutoClear(url);
        message = l10n!.copiedUrl;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
      final totpCode = _getTotpCode(activeEntry);
      if (totpCode != null) {
        copyToClipboardWithAutoClear(totpCode);
        message = l10n!.copiedTotp;
      }
    }

    if (message != null) {
      ScaffoldMessenger.of(navCtx).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0D9488),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _saveDatabase(
    BuildContext navCtx,
    AppLocalizations? l10n,
  ) async {
    final dbState = ref.read(databaseProvider);
    if (!dbState.hasValue || dbState.value == null) return;

    final notifier = ref.read(databaseProvider.notifier);
    final success = await notifier.save();
    if (!navCtx.mounted) return;

    // Local save may succeed while cloud sync reports conflict/error.
    final String message;
    final Color background;
    if (success) {
      message = l10n?.saved ?? 'Saved';
      background = const Color(0xFF0D9488);
    } else {
      final syncState = ref.read(syncStateProvider);
      if (syncState == SyncState.conflict) {
        message = l10n?.syncConflict ?? 'Sync conflict';
      } else if (syncState == SyncState.error) {
        message = l10n?.syncFailed ?? 'Sync failed';
      } else {
        message = l10n?.saveFailed ?? 'Save failed';
      }
      background = Colors.red;
    }
    ScaffoldMessenger.of(navCtx).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String? _getTotpCode(dynamic entry) {
    final config = TotpService().loadFromEntry(entry);
    if (config == null) return null;
    return TotpService().generateCode(config);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final effectiveLocale =
        locale ?? WidgetsBinding.instance.platformDispatcher.locale;
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);
    // Auto-save: schedule save when database becomes dirty.
    ref.listen(isDirtyProvider, (prev, next) {
      if (next) {
        ref.read(autoSaveProvider.notifier).resetTimer();
      }
    });

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) {
          ref.read(autoLockProvider.notifier).resetTimer();
          ref.read(autoSaveProvider.notifier).resetTimer();
        },
        onPointerSignal: (_) {
          ref.read(autoLockProvider.notifier).resetTimer();
          ref.read(autoSaveProvider.notifier).resetTimer();
        },
        child: Stack(
          textDirection: TextDirection.ltr,
          children: [
            MaterialApp.router(
              title: 'KeeVault',
              theme: AppTheme.light(locale: effectiveLocale),
              darkTheme: AppTheme.dark(locale: effectiveLocale),
              themeMode: themeMode,
              routerConfig: router,
              debugShowCheckedModeBanner: false,
              locale: locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('zh'), Locale('en')],
            ),
            if (_backgroundPrivacyVisible)
              Directionality(
                textDirection: TextDirection.ltr,
                child: const ColoredBox(
                  color: Color(0xFF111827),
                  child: Center(
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
