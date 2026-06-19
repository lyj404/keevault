import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/biometric_service.dart';

final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  return BiometricService().isBiometricAvailable();
});

final biometricEnabledProvider = StateNotifierProvider<BiometricEnabledNotifier, bool>((ref) {
  return BiometricEnabledNotifier();
});

class BiometricEnabledNotifier extends StateNotifier<bool> {
  BiometricEnabledNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    state = await BiometricService().isBiometricEnabled();
  }

  Future<void> setEnabled(bool enabled) async {
    await BiometricService().setBiometricEnabled(enabled);
    state = enabled;
  }
}
