import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';

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
    final msg = 'BiometricService: isBiometricAvailable called, isAndroid=${Platform.isAndroid}';
    debugPrint(msg);
    log.e(msg);
    if (!Platform.isAndroid) return false;
    try {
      final result = await biometric.isBiometricAvailable();
      final msg2 = 'BiometricService: isBiometricAvailable result=$result';
      debugPrint(msg2);
      log.e(msg2);
      return result;
    } catch (e) {
      final msg2 = 'BiometricService: Error checking biometric availability: $e';
      debugPrint(msg2);
      log.e(msg2);
      return false;
    }
  }

  Future<List<dynamic>> getAvailableBiometrics() async {
    if (!Platform.isAndroid) return [];
    try {
      return await biometric.getAvailableBiometrics();
    } catch (e) {
      final msg = 'BiometricService: Error getting available biometrics: $e';
      debugPrint(msg);
      log.e(msg);
      return [];
    }
  }

  Future<bool> authenticate(String reason) async {
    final msg = 'BiometricService: authenticate called, isAndroid=${Platform.isAndroid}';
    debugPrint(msg);
    log.e(msg);
    if (!Platform.isAndroid) return false;
    try {
      final result = await biometric.authenticate(reason);
      final msg2 = 'BiometricService: authenticate result=$result';
      debugPrint(msg2);
      log.e(msg2);
      return result;
    } catch (e) {
      final msg2 = 'BiometricService: Authentication error: $e';
      debugPrint(msg2);
      log.e(msg2);
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
