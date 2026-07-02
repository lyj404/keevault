import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'tray_service_desktop.dart';
import 'tray_service_linux.dart';

abstract class TrayServiceBase {
  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  });
  Future<void> dispose();
}

TrayServiceBase createTrayService() {
  if (Platform.isLinux) return createTrayServiceLinux();
  return createTrayServiceDesktop();
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

    _impl = createTrayService();
    await _impl!.init(
      showLabel: showLabel,
      exitLabel: exitLabel,
      onShowWindow: onShowWindow,
      onExitApp: onExitApp,
    );
  }

  Future<void> dispose() async {
    await _impl?.dispose();
  }
}
