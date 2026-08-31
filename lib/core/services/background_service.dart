import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Moves the app to the background (Android back-to-home behavior).
class BackgroundService {
  BackgroundService._();

  static const _channel = MethodChannel('com.keestone.keestone/privacy');

  /// Whether the current platform supports moving the app to the background.
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<void> moveToBackground() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('moveTaskToBack');
    } on PlatformException {
      // Ignore; the app simply stays in the foreground.
    } on MissingPluginException {
      // Ignore.
    }
  }
}
