import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/biometric_service.dart';
import '../data/csv_service.dart';
import '../data/database_service.dart';
import '../data/recent_files_service.dart';
export '../data/recent_files_service.dart' show RecentFile;
export '../data/csv_service.dart' show CsvEntry;
import '../../../core/providers/auto_lock_provider.dart';
import '../../backup/providers/backup_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/data/sync_service.dart' show RemoteFileInfo;
import '../../sync/providers/sync_provider.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final csvServiceProvider = Provider<CsvService>((ref) {
  return CsvService();
});

final recentFilesServiceProvider = Provider<RecentFilesService>((ref) {
  return RecentFilesService();
});

final databaseProvider = StateNotifierProvider<DatabaseNotifier, AsyncValue<KdbxDatabase?>>((ref) {
  return DatabaseNotifier(ref);
});

class DatabaseNotifier extends StateNotifier<AsyncValue<KdbxDatabase?>> {
  final Ref _ref;
  bool _disposed = false;

  DatabaseNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _service.onDirtyChanged = (isDirty) {
      Future.microtask(() {
        if (!_disposed) {
          _ref.read(isDirtyProvider.notifier).state = isDirty;
        }
      });
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  DatabaseService get _service => _ref.read(databaseServiceProvider);

  Future<void> preloadFile(String filePath) => _service.preloadFile(filePath);

  Future<void> openFile(String filePath, String password, {bool isCloud = false, String? syncedETag, Uint8List? keyData}) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.openFile(filePath, password, keyData: keyData);
      if (_disposed) return;
      String? remotePath;
      String? eTag = syncedETag;
      if (isCloud) {
        final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
        if (_disposed) return;
        if (config != null && config.enabled) {
          remotePath = config.remoteFilePath;
          if (syncedETag != null) {
            // Welcome screen already verified eTag, reuse it directly
            _service.setLastSyncedRemoteInfo(RemoteFileInfo(eTag: syncedETag));
          } else {
            final info = await _ref.read(syncServiceProvider).getRemoteFileInfo(config);
            _service.setLastSyncedRemoteInfo(info);
            eTag = info?.eTag;
          }
        }
      }
      final recentSvc = _ref.read(recentFilesServiceProvider);
      await Future.wait([
        recentSvc.addRecentFile(filePath, isCloud: isCloud, remotePath: remotePath, lastSyncedETag: eTag),
        recentSvc.setLastOpenedFile(filePath, isCloud: isCloud, remotePath: remotePath, lastSyncedETag: eTag),
      ]);
      if (_disposed) return;
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
    } catch (e, st) {
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDatabase(String name, String password, String filePath, {Uint8List? keyData}) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.createDatabase(name, password, filePath, keyData: keyData);
      if (_disposed) return;
      final recentSvc = _ref.read(recentFilesServiceProvider);
      await Future.wait([
        recentSvc.addRecentFile(filePath),
        recentSvc.setLastOpenedFile(filePath),
      ]);
      if (_disposed) return;
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
    } catch (e, st) {
      if (!_disposed) state = AsyncValue.error(e, st);
    }
  }

  /// Saves locally and syncs to WebDAV if enabled.
  /// Returns [SaveResult.success] on success, [SaveResult.conflict] if a conflict
  /// was detected, or [SaveResult.syncError] on network/sync failure.
  Future<SaveResult> save() async {
    final wasDirty = _service.isDirty;
    final bytes = await _service.save();
    if (bytes.isEmpty) return SaveResult.success;
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
    if (_disposed) return SaveResult.success;
    // Only sync to cloud if the current database was opened from or created as a cloud database
    if (config != null && config.enabled && _ref.read(openedFromCloudProvider)) {
      _ref.read(syncStateProvider.notifier).state = SyncState.syncing;
      try {
        final syncService = _ref.read(syncServiceProvider);
        // Conflict detection: check if remote changed since last sync
        final remoteInfo = await syncService.getRemoteFileInfo(config);
        final lastInfo = _service.lastSyncedRemoteInfo;
        if (remoteInfo != null && lastInfo != null &&
            remoteInfo.eTag != null && lastInfo.eTag != null &&
            remoteInfo.eTag != lastInfo.eTag) {
          _ref.read(syncStateProvider.notifier).state = SyncState.conflict;
          return SaveResult.conflict;
        }
        // Skip upload if local content hasn't changed since last save
        if (!wasDirty) {
          log.i('Content unchanged, skipping upload');
          _ref.read(syncStateProvider.notifier).state = SyncState.success;
          return SaveResult.success;
        }
        await syncService.ensureRemoteDirectory(config);
        await syncService.uploadDatabase(config, bytes);
        // Store the remote metadata after successful upload
        final newInfo = await syncService.getRemoteFileInfo(config);
        _service.setLastSyncedRemoteInfo(newInfo);
        // Persist the eTag so next startup can skip redundant download
        if (newInfo?.eTag != null && _service.filePath != null) {
          final recentSvc = _ref.read(recentFilesServiceProvider);
          final existing = await recentSvc.getRecentFiles();
          final wasCloud = existing.any((f) => f.path == _service.filePath && f.isCloud);
          await Future.wait([
            recentSvc.addRecentFile(_service.filePath!, isCloud: wasCloud, remotePath: config.remoteFilePath, lastSyncedETag: newInfo!.eTag),
            recentSvc.setLastOpenedFile(_service.filePath!, isCloud: wasCloud, remotePath: config.remoteFilePath, lastSyncedETag: newInfo.eTag),
          ]);
        }
        _ref.read(syncStateProvider.notifier).state = SyncState.success;
      } catch (e) {
        log.e('Sync failed', error: e);
        _ref.read(syncStateProvider.notifier).state = SyncState.error;
        return SaveResult.syncError;
      }
    }
    return SaveResult.success;
  }

  /// Force upload, ignoring conflict detection (used after user chooses to overwrite).
  /// Always creates a backup before overwriting, since this is a destructive operation.
  Future<void> forceUpload() async {
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) return;
    final backupSvc = _ref.read(backupServiceProvider);
    if (_service.filePath != null) {
      await backupSvc.createBackup(_service.filePath!);
    }
    _ref.read(syncStateProvider.notifier).state = SyncState.syncing;
    try {
      final syncService = _ref.read(syncServiceProvider);
      await syncService.ensureRemoteDirectory(config);
      final bytes = await _service.saveToBytes();
      await syncService.uploadDatabase(config, bytes);
      final newInfo = await syncService.getRemoteFileInfo(config);
      _service.setLastSyncedRemoteInfo(newInfo);
      // Persist the eTag so next startup doesn't see a false conflict
      if (newInfo?.eTag != null && _service.filePath != null) {
        final recentSvc = _ref.read(recentFilesServiceProvider);
        final existing = await recentSvc.getRecentFiles();
        final wasCloud = existing.any((f) => f.path == _service.filePath && f.isCloud);
        await Future.wait([
          recentSvc.addRecentFile(_service.filePath!, isCloud: wasCloud, remotePath: config.remoteFilePath, lastSyncedETag: newInfo!.eTag),
          recentSvc.setLastOpenedFile(_service.filePath!, isCloud: wasCloud, remotePath: config.remoteFilePath, lastSyncedETag: newInfo.eTag),
        ]);
      }
      _ref.read(syncStateProvider.notifier).state = SyncState.success;
    } catch (e) {
      _ref.read(syncStateProvider.notifier).state = SyncState.error;
    }
  }

  Future<void> saveAs(String newPath) async {
    await _service.saveAs(newPath);
  }

  void close() {
    _service.close();
    state = const AsyncValue.data(null);
    _ref.read(openedFromCloudProvider.notifier).state = false;
    unawaited(_ref.read(recentFilesServiceProvider).clearLastOpenedFile());
    _ref.read(autoLockProvider.notifier).cancelTimer();
    _ref.invalidate(recentFilesProvider);
  }

  Future<void> reloadFromCloud() async {
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) throw Exception('please_configure_webdav');
    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.downloadWithInfo(config);
    if (result == null) throw Exception('cloud_database_not_exist');
    final db = await _service.reloadFromBytes(result.bytes);
    if (_disposed) return;
    _service.setLastSyncedRemoteInfo(result.info);
    state = AsyncValue.data(db);
    if (_service.filePath != null) {
      final recentSvc = _ref.read(recentFilesServiceProvider);
      final existing = await recentSvc.getRecentFiles();
      final wasCloud = existing.any((f) => f.path == _service.filePath && f.isCloud);
      await Future.wait([
        recentSvc.addRecentFile(_service.filePath!, isCloud: wasCloud, remotePath: config.remoteFilePath, lastSyncedETag: result.info.eTag),
        recentSvc.setLastOpenedFile(_service.filePath!, isCloud: wasCloud, remotePath: config.remoteFilePath, lastSyncedETag: result.info.eTag),
      ]);
    }
  }

  /// Checks if the remote file has changed since last sync.
  /// Returns true if remote has newer changes (conflict).
  Future<bool> checkRemoteChanges() async {
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) return false;
    final syncService = _ref.read(syncServiceProvider);
    final remoteInfo = await syncService.getRemoteFileInfo(config);
    final lastInfo = _service.lastSyncedRemoteInfo;
    if (remoteInfo == null || lastInfo == null) return false;
    return remoteInfo.eTag != null && lastInfo.eTag != null &&
           remoteInfo.eTag != lastInfo.eTag;
  }

  Future<void> changePassword(String oldPassword, String newPassword, {bool updateKeyFile = false, Uint8List? newKeyData}) async {
    _service.changePassword(oldPassword, newPassword, updateKeyFile: updateKeyFile, newKeyData: newKeyData);
    // Update biometric stored password so fingerprint unlock still works after password change
    if (Platform.isAndroid && _service.filePath != null) {
      final bioService = BiometricService();
      if (await bioService.isBiometricEnabled()) {
        await bioService.storePassword(_service.filePath!, newPassword);
      }
    }
    // Save + sync to cloud if enabled.
    await save();
  }

  void markDirty() => _service.markDirty();
  bool get isDirty => _service.isDirty;
  bool get hasKeyFile => _service.hasKeyFile;
}

final recentFilesProvider = FutureProvider<List<RecentFile>>((ref) async {
  return ref.read(recentFilesServiceProvider).getRecentFiles();
});

/// Whether the current database was opened from WebDAV (cloud).
final openedFromCloudProvider = StateProvider<bool>((ref) => false);

/// Whether the database has unsaved changes.
final isDirtyProvider = StateProvider<bool>((ref) => false);

/// Result of a save operation that distinguishes success from conflict vs sync error.
enum SaveResult { success, conflict, syncError }
