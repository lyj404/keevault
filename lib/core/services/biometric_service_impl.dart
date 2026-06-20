import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import '../utils/logger.dart';

Future<bool> isBiometricAvailable() async {
  final platform = LocalAuthPlatform.instance;
  final supported = await platform.isDeviceSupported();
  log.e('Biometric: isDeviceSupported=$supported');
  if (supported) {
    final enrolled = await platform.getEnrolledBiometrics();
    log.e('Biometric: enrolled=${enrolled.map((e) => e.name).toList()}');
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
    log.e('Biometric: starting authenticate, reason=$reason');
    final result = await platform.authenticate(
      localizedReason: reason,
      authMessages: const [AndroidAuthMessages()],
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false,
      ),
    );
    log.e('Biometric: authenticate result=$result');
    return result;
  } catch (e, st) {
    log.e('Biometric: authenticate error=$e\n$st');
    return false;
  }
}
