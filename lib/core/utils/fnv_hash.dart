import 'dart:convert';
import 'dart:typed_data';

/// FNV-1a 64-bit hash utilities for fast byte/string comparison.
class FnvHash {
  FnvHash._();

  /// Hashes raw bytes and returns an integer hash.
  static int hashBytes(Uint8List bytes) {
    int hash = 0xcbf29ce484222325;
    const int prime = 0x100000001b3;
    for (int i = 0; i < bytes.length; i++) {
      hash ^= bytes[i];
      hash = (hash * prime) & 0x7FFFFFFFFFFFFFFF;
    }
    return hash;
  }

  /// Hashes a string (UTF-8 encoded) and returns a hex string.
  static String hashString(String input) {
    final bytes = utf8.encode(input);
    return hashBytes(bytes).toRadixString(16);
  }
}
