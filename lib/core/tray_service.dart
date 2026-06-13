import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';

class TrayService {
  static final TrayService _instance = TrayService._();
  factory TrayService() => _instance;
  TrayService._();

  final SystemTray _tray = SystemTray();
  bool _initialized = false;

  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (_initialized) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;

    final String iconPath = Platform.isWindows
        ? 'assets/icons/app_icon.ico'
        : 'assets/icons/app_icon.png';

    await _tray.initSystemTray(
      title: 'KeeVault',
      iconPath: iconPath,
    );

    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(label: showLabel, onClicked: (_) => onShowWindow()),
      MenuItemLabel(label: exitLabel, onClicked: (_) => onExitApp()),
    ]);

    await _tray.setContextMenu(menu);
    _tray.registerSystemTrayEventHandler((String eventType) {
      if (eventType == kSystemTrayEventClick) {
        onShowWindow();
      } else if (eventType == kSystemTrayEventDoubleClick) {
        onShowWindow();
      }
    });

    _initialized = true;
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _tray.destroy();
      _initialized = false;
    }
  }
}
