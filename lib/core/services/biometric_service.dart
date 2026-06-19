import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Conditional import - only import on Android
import 'biometric_service_impl_stub.dart'
    if (dart.library.io) 'biometric_service_impl.dart' as biometric;

class BiometricService {
  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;
  BiometricService._();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _storedPasswordPrefix = 'biometric_password_';

  Future<bool> isBiometricAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await biometric.isBiometricAvailable();
    } catch (e) {
      debugPrint('BiometricService: Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<dynamic>> getAvailableBiometrics() async {
    if (!Platform.isAndroid) return [];
    try {
      return await biometric.getAvailableBiometrics();
    } catch (e) {
      debugPrint('BiometricService: Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticate(String reason) async {
    if (!Platform.isAndroid) return false;
    try {
      return await biometric.authenticate(reason);
    } catch (e) {
      debugPrint('BiometricService: Authentication error: $e');
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
    return path.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }
}
