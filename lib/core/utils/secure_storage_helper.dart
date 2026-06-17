import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A wrapper around [FlutterSecureStorage] that gracefully handles
/// Windows DPAPI corruption errors (CryptUnprotectData failure).
///
/// On Windows, the secure storage file can become unreadable after
/// Windows updates, user profile changes, or file corruption. When
/// this happens, the package deletes the corrupt file and throws.
/// This wrapper catches the error and returns null/default values
/// so the app can continue working.
class SecureStorageHelper {
  final FlutterSecureStorage _storage;

  const SecureStorageHelper([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // DPAPI decryption failed; the package already deleted the corrupt file.
      // Subsequent reads will return null from a clean state.
      return null;
    }
  }

  Future<void> write({required String key, required String? value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      // If write fails (e.g. corrupt file still present), delete and retry.
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
