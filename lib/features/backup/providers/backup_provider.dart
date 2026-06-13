import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});

final backupListProvider = FutureProvider<List<BackupInfo>>((ref) async {
  return ref.read(backupServiceProvider).listBackups();
});

final backupRetentionProvider = FutureProvider<int>((ref) async {
  return ref.read(backupServiceProvider).getRetentionCount();
});

final autoBackupEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.read(backupServiceProvider).isAutoBackupEnabled();
});
