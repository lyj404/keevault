import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What happens when the user clicks the window close button.
enum CloseBehavior {
  /// Show a dialog every time asking exit or minimize.
  ask,

  /// Always minimize to system tray.
  minimizeToTray,

  /// Always exit the application.
  exit,
}

final closeBehaviorProvider = StateNotifierProvider<CloseBehaviorNotifier, CloseBehavior>((ref) {
  return CloseBehaviorNotifier();
});

class CloseBehaviorNotifier extends StateNotifier<CloseBehavior> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'close_behavior';

  CloseBehaviorNotifier() : super(CloseBehavior.ask) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value == 'exit') state = CloseBehavior.exit;
    if (value == 'minimizeToTray') state = CloseBehavior.minimizeToTray;
    if (value == 'ask' || value == null) state = CloseBehavior.ask;
  }

  Future<void> setCloseBehavior(CloseBehavior behavior) async {
    state = behavior;
    await _storage.write(key: _key, value: behavior.name);
  }
}
