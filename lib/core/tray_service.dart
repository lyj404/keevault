import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Conditional import: use system_tray on Windows/macOS, dart_xdg_status_notifier_item on Linux
import 'tray_service_desktop.dart'
    if (dart.library.io) 'tray_service_linux.dart';

abstract class TrayServiceBase {
  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  });
  Future<void> dispose();
}

class TrayService {
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;
  TrayService._();

  TrayServiceBase? _impl;

  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    try {
      _impl = createTrayService();
      await _impl!.init(
        showLabel: showLabel,
        exitLabel: exitLabel,
        onShowWindow: onShowWindow,
        onExitApp: onExitApp,
      );
    } catch (e) {
      debugPrint('TrayService: Initialization failed: $e');
    }
  }

  Future<void> dispose() async {
    await _impl?.dispose();
  }
}
