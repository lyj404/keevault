class AppConstants {
  static const clipboardClearTimeout = Duration(seconds: 30);
  static const searchDebounceDelay = Duration(milliseconds: 300);
  static const maxRecentFiles = 10;
  static const appName = 'KeeVault';
  static const kdbxExtension = '.kdbx';
  
  /// Standard KDBX field keys.
  static const standardKeys = {'Title', 'UserName', 'Password', 'URL', 'Notes'};
}
