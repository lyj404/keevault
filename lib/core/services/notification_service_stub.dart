/// Stub implementation for non-Windows platforms.
class WindowsNotificationHelper {
  void showBalloon(String title, String body) {
    // No-op on non-Windows platforms
  }

  void dispose() {}
}
