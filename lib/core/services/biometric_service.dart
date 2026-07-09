import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../utils/fnv_hash.dart';
import '../utils/logger.dart';
import '../utils/secure_storage_helper.dart';

// Conditional import - only import on Android
import 'biometric_service_impl_stub.dart'
    if (dart.library.io) 'biometric_service_impl.dart'
    as biometric;

class BiometricService {
  static final BiometricService _instance = BiometricService._();
  factory BiometricService() => _instance;
  BiometricService._();

  static const _secureStorage = SecureStorageHelper();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _storedPasswordPrefix = 'biometric_password_';
  static const String _storedKeyDataPrefix = 'biometric_key_data_';
  static const String _storedKeyFileNamePrefix = 'biometric_key_file_name_';

  Future<bool> isBiometricAvailable() async {
    log.d(
      'BiometricService: isBiometricAvailable called, isAndroid=${Platform.isAndroid}',
    );
    if (!Platform.isAndroid) return false;
    try {
      final result = await biometric.isBiometricAvailable();
      log.d('BiometricService: isBiometricAvailable result=$result');
      return result;
    } catch (e) {
      log.e(
        'BiometricService: Error checking biometric availability',
        error: e,
      );
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
    log.d(
      'BiometricService: authenticate called, isAndroid=${Platform.isAndroid}',
    );
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
    await _secureStorage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<void> storePassword(String databasePath, String password) async {
    await storeCredentials(databasePath, password);
  }

  Future<String?> getStoredPassword(String databasePath) async {
    final key = '$_storedPasswordPrefix${_hashPath(databasePath)}';
    return await _secureStorage.read(key: key);
  }

  Future<void> storeCredentials(
    String databasePath,
    String password, {
    Uint8List? keyData,
    String? keyFileName,
  }) async {
    final pathHash = _hashPath(databasePath);
    await _secureStorage.write(
      key: '$_storedPasswordPrefix$pathHash',
      value: password,
    );
    await _secureStorage.write(
      key: '$_storedKeyDataPrefix$pathHash',
      value: keyData != null ? base64Encode(keyData) : null,
    );
    await _secureStorage.write(
      key: '$_storedKeyFileNamePrefix$pathHash',
      value: keyFileName,
    );
  }

  Future<StoredBiometricCredentials?> getStoredCredentials(
    String databasePath,
  ) async {
    final pathHash = _hashPath(databasePath);
    final password = await _secureStorage.read(
      key: '$_storedPasswordPrefix$pathHash',
    );
    if (password == null || password.isEmpty) return null;

    final keyDataEncoded = await _secureStorage.read(
      key: '$_storedKeyDataPrefix$pathHash',
    );
    final keyFileName = await _secureStorage.read(
      key: '$_storedKeyFileNamePrefix$pathHash',
    );

    Uint8List? keyData;
    if (keyDataEncoded != null && keyDataEncoded.isNotEmpty) {
      try {
        keyData = Uint8List.fromList(base64Decode(keyDataEncoded));
      } catch (e) {
        log.w('BiometricService: failed to decode stored key data: $e');
      }
    }

    return StoredBiometricCredentials(
      password: password,
      keyData: keyData,
      keyFileName: keyFileName,
    );
  }

  Future<void> removeStoredPassword(String databasePath) async {
    final pathHash = _hashPath(databasePath);
    await _secureStorage.delete(key: '$_storedPasswordPrefix$pathHash');
    await _secureStorage.delete(key: '$_storedKeyDataPrefix$pathHash');
    await _secureStorage.delete(key: '$_storedKeyFileNamePrefix$pathHash');
  }

  Future<void> clearAllStoredPasswords() async {
    final all = await _secureStorage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_storedPasswordPrefix) ||
          key.startsWith(_storedKeyDataPrefix) ||
          key.startsWith(_storedKeyFileNamePrefix)) {
        await _secureStorage.delete(key: key);
      }
    }
  }

  String _hashPath(String path) => FnvHash.hashString(path);
}

class StoredBiometricCredentials {
  final String password;
  final Uint8List? keyData;
  final String? keyFileName;

  const StoredBiometricCredentials({
    required this.password,
    this.keyData,
    this.keyFileName,
  });
}
