import 'dart:ffi';
import 'dart:io';
import 'package:kpasslib/kpasslib.dart';
import '../utils/logger.dart';

class CryptoService {
  static bool _initialized = false;
  static bool _ffiAvailable = false;

  static bool get isFfiAvailable => _ffiAvailable;

  /// Initializes the crypto engine with native FFI if available.
  /// Must be called before any KDBX operations.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    try {
      final lib = _loadNativeLibrary();
      if (lib != null) {
        Crypto.engine = CryptoFfi(lib);
        _ffiAvailable = true;
        log.i('Native crypto engine (CryptoFfi) initialized');
      } else {
        log.i('Native crypto library not found, using pure Dart engine');
      }
    } catch (e) {
      log.w('Failed to initialize native crypto: $e, using pure Dart engine');
    }
  }

  static DynamicLibrary? _loadNativeLibrary() {
    if (Platform.isLinux) {
      return _tryLoad('libkreepto.so');
    } else if (Platform.isMacOS) {
      return _tryLoad('libkreepto.dylib');
    } else if (Platform.isWindows) {
      // Windows: DLL is bundled next to the executable
      return _tryLoad('kreepto.dll');
    } else if (Platform.isAndroid) {
      // Android: .so is bundled in jniLibs by Gradle
      return _tryLoad('libkreepto.so');
    } else if (Platform.isIOS) {
      try {
        return DynamicLibrary.process();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static DynamicLibrary? _tryLoad(String name) {
    try {
      return DynamicLibrary.open(name);
    } catch (_) {
      return null;
    }
  }
}
