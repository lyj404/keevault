import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts and decrypts WebDAV passwords using XOR stream cipher
/// with a device-bound key stored in secure storage.
class PasswordEncryptor {
  static const _keyStorageName = 'webdav_enc_key';
  static const _ivLength = 16;
  /// Marker prefix to distinguish encrypted passwords from plaintext.
  static const encryptedMarker = 'ENC:';

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

  /// Returns true if the password is already encrypted (has the marker prefix).
  bool isEncrypted(String password) => password.startsWith(encryptedMarker);

  /// Encrypts a plaintext password. Returns a string with the ENC: prefix
  /// followed by base64url-encoded IV+ciphertext.
  Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return '';
    if (isEncrypted(plaintext)) return plaintext;

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
    return '$encryptedMarker${base64Url.encode(result)}';
  }

  /// Decrypts an encrypted password string produced by [encrypt].
  /// If the string doesn't have the ENC: prefix, returns it as-is (legacy plaintext).
  Future<String> decrypt(String encryptedPassword) async {
    if (encryptedPassword.isEmpty) return '';
    if (!isEncrypted(encryptedPassword)) return encryptedPassword;

    final base64Data = encryptedPassword.substring(encryptedMarker.length);
    final key = await _getOrCreateKey();
    final data = base64Url.decode(base64Data);

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
