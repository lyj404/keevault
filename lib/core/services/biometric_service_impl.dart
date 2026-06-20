import 'package:flutter/foundation.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import '../utils/logger.dart';

Future<bool> isBiometricAvailable() async {
  final platform = LocalAuthPlatform.instance;
  final supported = await platform.isDeviceSupported();
  final msg = 'Biometric: isDeviceSupported=$supported';
  debugPrint(msg);
  log.e(msg);
  if (supported) {
    final enrolled = await platform.getEnrolledBiometrics();
    final msg2 = 'Biometric: enrolled=${enrolled.map((e) => e.name).toList()}';
    debugPrint(msg2);
    log.e(msg2);
  }
  return supported;
}

Future<List<BiometricType>> getAvailableBiometrics() async {
  final platform = LocalAuthPlatform.instance;
  return await platform.getEnrolledBiometrics();
}

Future<bool> authenticate(String reason) async {
  final platform = LocalAuthPlatform.instance;
  try {
    final msg = 'Biometric: starting authenticate, reason=$reason';
    debugPrint(msg);
    log.e(msg);
    final result = await platform.authenticate(
      localizedReason: reason,
      authMessages: const [AndroidAuthMessages()],
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    final msg2 = 'Biometric: authenticate result=$result';
    debugPrint(msg2);
    log.e(msg2);
    return result;
  } catch (e, st) {
    final msg = 'Biometric: authenticate error=$e\n$st';
    debugPrint(msg);
    log.e(msg);
    return false;
  }
}
