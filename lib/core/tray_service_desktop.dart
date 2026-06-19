import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'tray_service.dart';

TrayServiceBase createTrayService() => TrayServiceDesktop();

class TrayServiceDesktop implements TrayServiceBase {
  final SystemTray _tray = SystemTray();
  bool _initialized = false;

  @override
  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (_initialized) return;

    String iconPath;
    if (Platform.isWindows) {
      iconPath = 'assets/icons/app_icon.ico';
    } else {
      // macOS: AppIndicator needs absolute path
      final exePath = Platform.resolvedExecutable;
      final exeDir = exePath.substring(0, exePath.lastIndexOf(Platform.pathSeparator));
      final releasePath = '$exeDir/data/flutter_assets/assets/icons/app_icon.png';
      final debugPath = '$exeDir/../../../data/flutter_assets/assets/icons/app_icon.png';

      if (File(releasePath).existsSync()) {
        iconPath = releasePath;
      } else if (File(debugPath).existsSync()) {
        iconPath = File(debugPath).resolveSymbolicLinksSync();
      } else {
        iconPath = releasePath;
      }
    }

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
      } else if (eventType == kSystemTrayEventRightClick) {
        _tray.popUpContextMenu();
      }
    });

    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _tray.destroy();
      _initialized = false;
    }
  }
}
