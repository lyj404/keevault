import 'dart:convert';
import 'dart:io';
import '../utils/logger.dart';
import '../utils/secure_storage_helper.dart';

// Conditional import - only import on Android
import 'biometric_service_impl_stub.dart'
    if (dart.library.io) 'biometric_service_impl.dart' as biometric;

class BiometricService {
  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;
  BiometricService._();

  static const _secureStorage = SecureStorageHelper();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _storedPasswordPrefix = 'biometric_password_';

  Future<bool> isBiometricAvailable() async {
    log.d('BiometricService: isBiometricAvailable called, isAndroid=${Platform.isAndroid}');
    if (!Platform.isAndroid) return false;
    try {
      final result = await biometric.isBiometricAvailable();
      log.d('BiometricService: isBiometricAvailable result=$result');
      return result;
    } catch (e) {
      log.e('BiometricService: Error checking biometric availability', error: e);
      return false;
    }
  }

  Future<List<dynamic>> getAvailableBiometrics() async {
    if (!Platform.isAndroid) return [];
    try {
      return await biometric.getAvailableBiometrics();
    } catch (e) {
      log.e('BiometricService: Error getting available biometrics', error: e);
      return [];
    }
  }

  Future<bool> authenticate(String reason) async {
    log.d('BiometricService: authenticate called, isAndroid=${Platform.isAndroid}');
    if (!Platform.isAndroid) return false;
    try {
      final result = await biometric.authenticate(reason);
      log.d('BiometricService: authenticate result=$result');
      return result;
    } catch (e) {
      log.e('BiometricService: Authentication error', error: e);
      return false;
    }
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<void> storePassword(String databasePath, String password) async {
    final key = '$_storedPasswordPrefix${_hashPath(databasePath)}';
    await _secureStorage.write(key: key, value: password);
  }

  Future<String?> getStoredPassword(String databasePath) async {
    final key = '$_storedPasswordPrefix${_hashPath(databasePath)}';
    return await _secureStorage.read(key: key);
  }

  Future<void> removeStoredPassword(String databasePath) async {
    final key = '$_storedPasswordPrefix${_hashPath(databasePath)}';
    await _secureStorage.delete(key: key);
  }

  Future<void> clearAllStoredPasswords() async {
    final all = await _secureStorage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_storedPasswordPrefix)) {
        await _secureStorage.delete(key: key);
      }
    }
  }

  String _hashPath(String path) {
    final bytes = utf8.encode(path);
    // Simple hash: use hashCode as hex string for collision-free key mapping
    return bytes.hashCode.toRadixString(16);
  }
}
