import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

Future<bool> isBiometricAvailable() async {
  final platform = LocalAuthPlatform.instance;
  return await platform.isDeviceSupported();
}

Future<List<BiometricType>> getAvailableBiometrics() async {
  final platform = LocalAuthPlatform.instance;
  return await platform.getEnrolledBiometrics();
}

Future<bool> authenticate(String reason) async {
  final platform = LocalAuthPlatform.instance;
  return await platform.authenticate(
    localizedReason: reason,
    authMessages: const [AndroidAuthMessages()],
    options: const AuthenticationOptions(
      stickyAuth: true,
      biometricOnly: true,
    ),
  );
}
