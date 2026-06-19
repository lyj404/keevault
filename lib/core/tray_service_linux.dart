import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dart_xdg_status_notifier_item/dart_xdg_status_notifier_item.dart';
import 'tray_service.dart';

TrayServiceBase createTrayService() => TrayServiceLinux();

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
    if (File(releasePath).existsSync()) {
      iconPath = releasePath;
    } else if (File(debugPath).existsSync()) {
      iconPath = File(debugPath).resolveSymbolicLinksSync();
    } else {
      iconPath = releasePath;
    }

    debugPrint('TrayServiceLinux: Using icon path: $iconPath');

    // Create menu items
    final menu = DBusMenuItem(children: [
      DBusMenuItem(
        label: showLabel,
        onClicked: () async {
          debugPrint('TrayServiceLinux: Show window clicked');
          onShowWindow();
        },
      ),
      DBusMenuItem.separator(),
      DBusMenuItem(
        label: exitLabel,
        onClicked: () async {
          debugPrint('TrayServiceLinux: Exit clicked');
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
      debugPrint('TrayServiceLinux: Connecting to D-Bus...');
      await _client!.connect();
      _initialized = true;
      debugPrint('TrayServiceLinux: Connected successfully');
    } catch (e, stackTrace) {
      debugPrint('TrayServiceLinux: Failed to connect: $e');
      debugPrint('TrayServiceLinux: Stack trace: $stackTrace');
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
