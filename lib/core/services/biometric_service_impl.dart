import 'package:local_auth/local_auth.dart';

final LocalAuthentication _localAuth = LocalAuthentication();

Future<bool> isBiometricAvailable() async {
  return await _localAuth.canCheckBiometrics;
}

Future<List<BiometricType>> getAvailableBiometrics() async {
  return await _localAuth.getAvailableBiometrics();
}

Future<bool> authenticate(String reason) async {
  return await _localAuth.authenticate(
    localizedReason: reason,
    options: const AuthenticationOptions(
      stickyAuth: true,
      biometricOnly: true,
    ),
  );
}
