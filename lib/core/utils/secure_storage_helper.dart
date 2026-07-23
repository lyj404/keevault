import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger.dart';

class SecureStorageWriteException implements Exception {
  final String key;
  final Object cause;
  const SecureStorageWriteException(this.key, this.cause);

  @override
  String toString() => 'SecureStorageWriteException(key: $key, cause: $cause)';
}

/// A wrapper around [FlutterSecureStorage] that gracefully handles
/// Windows DPAPI corruption errors (CryptUnprotectData failure).
///
/// On Windows, the secure storage file can become unreadable after
/// Windows updates, user profile changes, or file corruption. The
/// native plugin prints the error and deletes the file — this is
/// a one-time cost that cannot be suppressed. This wrapper catches
/// the thrown exception so the app continues working.
class SecureStorageHelper {
  final FlutterSecureStorage _storage;
  static Future<void> _pending = Future.value();

  const SecureStorageHelper([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending = _pending.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<String?> read({required String key}) async {
    return _serialize(() async {
      try {
        return await _storage.read(key: key);
      } catch (e) {
        log.w('SecureStorage read failed for key: $key', error: e);
        return null;
      }
    });
  }

  Future<void> write({required String key, required String? value}) async {
    await _serialize(() async {
      try {
        await _storage.write(key: key, value: value);
      } catch (e) {
        log.w(
          'SecureStorage write failed for key: $key, retrying with recovery',
          error: e,
        );
        try {
          if (Platform.isWindows) {
            // The Windows plugin stores all values in a single DPAPI-backed
            // file. After a corruption recovery path, the plugin may still be
            // releasing its file handle, so retry the write after a short delay
            // instead of issuing another delete against the locked file.
            await Future<void>.delayed(const Duration(milliseconds: 250));
            await _storage.write(key: key, value: value);
            return;
          }
          await _storage.delete(key: key);
          await _storage.write(key: key, value: value);
        } catch (e2) {
          log.e(
            'SecureStorage retry write also failed for key: $key',
            error: e2,
          );
          throw SecureStorageWriteException(key, e2);
        }
      }
    });
  }

  Future<void> delete({required String key}) async {
    await _serialize(() async {
      try {
        await _storage.delete(key: key);
      } catch (e) {
        log.w('SecureStorage delete failed for key: $key', error: e);
      }
    });
  }

  Future<Map<String, String>> readAll() async {
    return _serialize(() async {
      try {
        return await _storage.readAll();
      } catch (e) {
        log.w('SecureStorage readAll failed', error: e);
        return {};
      }
    });
  }
}
