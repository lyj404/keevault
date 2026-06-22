import 'package:flutter/foundation.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import '../utils/logger.dart';

Future<bool> isBiometricAvailable() async {
  final platform = LocalAuthPlatform.instance;
  final supported = await platform.isDeviceSupported();
  log.d('Biometric: isDeviceSupported=$supported');
  if (supported) {
    final enrolled = await platform.getEnrolledBiometrics();
    log.d('Biometric: enrolled=${enrolled.map((e) => e.name).toList()}');
    return enrolled.isNotEmpty;
  }
  return false;
}

Future<List<BiometricType>> getAvailableBiometrics() async {
  final platform = LocalAuthPlatform.instance;
  return await platform.getEnrolledBiometrics();
}

Future<bool> authenticate(String reason) async {
  final platform = LocalAuthPlatform.instance;
  try {
    log.d('Biometric: starting authenticate, reason=$reason');
    final result = await platform.authenticate(
      localizedReason: reason,
      authMessages: const [AndroidAuthMessages()],
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    log.d('Biometric: authenticate result=$result');
    return result;
  } catch (e, st) {
    log.e('Biometric: authenticate error', error: e, stackTrace: st);
    return false;
  }
}
