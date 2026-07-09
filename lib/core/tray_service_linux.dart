import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dart_xdg_status_notifier_item/dart_xdg_status_notifier_item.dart';
import 'utils/logger.dart';
import 'tray_service.dart';

TrayServiceBase createTrayServiceLinux() => TrayServiceLinux();

class TrayServiceLinux implements TrayServiceBase {
  StatusNotifierItemClient? _client;
  bool _initialized = false;

  @override
  Future<void> init({
    required String showLabel,
    required String exitLabel,
    required VoidCallback onShowWindow,
    required VoidCallback onExitApp,
  }) async {
    if (_initialized) return;

    // Get icon path
    final exePath = Platform.resolvedExecutable;
    final exeDir = exePath.substring(0, exePath.lastIndexOf(Platform.pathSeparator));
    final releasePath = '$exeDir/data/flutter_assets/assets/icons/app_icon.png';
    final debugPath = '$exeDir/../../../data/flutter_assets/assets/icons/app_icon.png';

    String iconPath;
    if (await File(releasePath).exists()) {
      iconPath = releasePath;
    } else if (await File(debugPath).exists()) {
      iconPath = await File(debugPath).resolveSymbolicLinks();
    } else {
      iconPath = releasePath;
    }

    log.d('TrayServiceLinux: Using icon path: $iconPath');

    // Create menu items
    final menu = DBusMenuItem(children: [
      DBusMenuItem(
        label: showLabel,
        onClicked: () async {
          log.d('TrayServiceLinux: Show window clicked');
          onShowWindow();
        },
      ),
      DBusMenuItem.separator(),
      DBusMenuItem(
        label: exitLabel,
        onClicked: () async {
          log.d('TrayServiceLinux: Exit clicked');
          onExitApp();
        },
      ),
    ]);

    // Create StatusNotifierItem client
    _client = StatusNotifierItemClient(
      id: 'keevault',
      iconName: iconPath,
      menu: menu,
    );

    try {
      log.d('TrayServiceLinux: Connecting to D-Bus...');
      await _client!.connect();
      _initialized = true;
      log.d('TrayServiceLinux: Connected successfully');
    } catch (e, stackTrace) {
      log.e('TrayServiceLinux: Failed to connect', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> dispose() async {
    if (_initialized) {
      await _client?.close();
      _initialized = false;
    }
  }
}
