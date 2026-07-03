import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/secure_storage_helper.dart';
import '../../features/database/providers/database_provider.dart';

const autoSaveDelayOptions = [0, 15, 30, 60, 120, 300]; // seconds, 0 = disabled

class AutoSaveNotifier extends StateNotifier<int> {
  static const _storage = SecureStorageHelper();
  static const _key = 'auto_save_seconds';
  final Ref _ref;
  Timer? _timer;

  AutoSaveNotifier(this._ref) : super(0) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    if (value != null) {
      state = int.tryParse(value) ?? 0;
    }
  }

  Future<void> setSeconds(int seconds) async {
    state = seconds;
    await _storage.write(key: _key, value: seconds.toString());
    _timer?.cancel();
    _scheduleIfDirty();
  }

  /// Called when database becomes dirty or user activity occurs.
  void resetTimer() {
    _timer?.cancel();
    _scheduleIfDirty();
  }

  void _scheduleIfDirty() {
    if (state <= 0) return;
    final dbState = _ref.read(databaseProvider);
    final hasDb = dbState.valueOrNull != null;
    final isDirty = _ref.read(isDirtyProvider);
    if (!hasDb || !isDirty) return;

    _timer = Timer(Duration(seconds: state), _save);
  }

  Future<void> _save() async {
    final dbState = _ref.read(databaseProvider);
    final hasDb = dbState.valueOrNull != null;
    final isDirty = _ref.read(isDirtyProvider);
    if (!hasDb || !isDirty) return;

    try {
      await _ref.read(databaseProvider.notifier).save();
    } catch (_) {
      // Auto-save failure is silent; user can manually save.
    }
  }

  void cancelTimer() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final autoSaveProvider = StateNotifierProvider<AutoSaveNotifier, int>((ref) {
  return AutoSaveNotifier(ref);
});

final autoSaveDelayOptionsProvider = Provider<List<int>>((ref) {
  return autoSaveDelayOptions;
});