import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/auto_lock_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/utils/clipboard_utils.dart';
import 'features/explorer/providers/explorer_provider.dart';
import 'features/totp/data/totp_service.dart';
import 'l10n/app_localizations.dart';

class KeeVaultApp extends ConsumerStatefulWidget {
  const KeeVaultApp({super.key});

  @override
  ConsumerState<KeeVaultApp> createState() => _KeeVaultAppState();
}

class _KeeVaultAppState extends ConsumerState<KeeVaultApp> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrl) return KeyEventResult.ignored;

    final activeEntry = ref.read(activeEntryProvider);
    if (activeEntry == null) return KeyEventResult.ignored;

    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx == null) return KeyEventResult.ignored;

    String? message;
    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      final username = activeEntry.fields['UserName']?.text ?? '';
      if (username.isNotEmpty) {
        copyToClipboardWithAutoClear(username);
        message = AppLocalizations.of(navCtx)!.copiedUsername;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final password = activeEntry.fields['Password']?.text ?? '';
      if (password.isNotEmpty) {
        copyToClipboardWithAutoClear(password);
        message = AppLocalizations.of(navCtx)!.copiedPassword;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyU) {
      final url = activeEntry.fields['URL']?.text ?? '';
      if (url.isNotEmpty) {
        copyToClipboardWithAutoClear(url);
        message = AppLocalizations.of(navCtx)!.copiedUrl;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
      final totpCode = _getTotpCode(activeEntry);
      if (totpCode != null) {
        copyToClipboardWithAutoClear(totpCode);
        message = AppLocalizations.of(navCtx)!.copiedTotp;
      }
    }

    if (message != null) {
      ScaffoldMessenger.of(navCtx).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF388E3C),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String? _getTotpCode(dynamic entry) {
    final cd = entry.customData;
    if (cd == null) return null;
    final secret = cd.map['TimeOtp-Secret']?.value;
    if (secret == null || secret.isEmpty) return null;
    final period = int.tryParse(cd.map['TimeOtp-Period']?.value ?? '') ?? 30;
    final digits = int.tryParse(cd.map['TimeOtp-Size']?.value ?? '') ?? 6;
    final algorithm = cd.map['TimeOtp-Algorithm']?.value ?? 'HMAC-SHA-1';
    final config = TotpConfig(secret: secret, period: period, digits: digits, algorithm: algorithm);
    return TotpService().generateCode(config);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
        onPointerHover: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
        onPointerSignal: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
        child: MaterialApp.router(
        title: 'KeeVault',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh'),
          Locale('en'),
        ],
      ),
      ),
    );
  }
}
