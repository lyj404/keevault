import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts and decrypts WebDAV passwords using XOR stream cipher
/// with a device-bound key stored in secure storage.
class PasswordEncryptor {
  static const _keyStorageName = 'webdav_enc_key';
  static const _ivLength = 16;

  final FlutterSecureStorage _storage;
  Uint8List? _cachedKey;

  PasswordEncryptor([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  /// Returns the device-bound encryption key, generating one if needed.
  Future<Uint8List> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final existing = await _storage.read(key: _keyStorageName);
    if (existing != null) {
      _cachedKey = base64Url.decode(existing);
      return _cachedKey!;
    }

    // Generate a new 256-bit key
    final random = Random.secure();
    final key = Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
    await _storage.write(key: _keyStorageName, value: base64Url.encode(key));
    _cachedKey = key;
    return key;
  }

  /// Encrypts a plaintext password. Returns a base64url string containing
  /// the IV prepended to the ciphertext.
  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return '';

    final key = await _getOrCreateKey();
    final iv = _generateIv();

    // Derive a keystream from key + IV by repeated XOR mixing
    final plainBytes = utf8.encode(plaintext);
    final encrypted = Uint8List(plainBytes.length);
    for (var i = 0; i < plainBytes.length; i++) {
      final k = key[i % key.length] ^ iv[i % iv.length];
      encrypted[i] = plainBytes[i] ^ k;
    }

    // Prepend IV to ciphertext
    final result = Uint8List(iv.length + encrypted.length);
    result.setRange(0, iv.length, iv);
    result.setRange(iv.length, result.length, encrypted);
    return base64Url.encode(result);
  }

  /// Decrypts an encrypted password string produced by [encrypt].
  Future<String> decrypt(String encryptedBase64) async {
    if (encryptedBase64.isEmpty) return '';

    final key = await _getOrCreateKey();
    final data = base64Url.decode(encryptedBase64);

    if (data.length <= _ivLength) return '';

    final iv = data.sublist(0, _ivLength);
    final ciphertext = data.sublist(_ivLength);

    final decrypted = Uint8List(ciphertext.length);
    for (var i = 0; i < ciphertext.length; i++) {
      final k = key[i % key.length] ^ iv[i % iv.length];
      decrypted[i] = ciphertext[i] ^ k;
    }
    return utf8.decode(decrypted);
  }

  Uint8List _generateIv() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(_ivLength, (_) => random.nextInt(256)),
    );
  }
}
