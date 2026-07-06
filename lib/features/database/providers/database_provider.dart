import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/utils/logger.dart';
import '../data/csv_service.dart';
import '../data/database_service.dart';
import '../data/recent_files_service.dart';
export '../data/recent_files_service.dart' show RecentFile;
export '../data/csv_service.dart' show CsvEntry;
import '../../../core/providers/auto_lock_provider.dart';
import '../../../core/providers/auto_save_provider.dart';
import '../../../core/providers/expiration_reminder_provider.dart';
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

final databaseProvider =
    StateNotifierProvider<DatabaseNotifier, AsyncValue<KdbxDatabase?>>((ref) {
      return DatabaseNotifier(ref);
    });

class DatabaseNotifier extends StateNotifier<AsyncValue<KdbxDatabase?>> {
  final Ref _ref;
  Object? _lastSyncError;
  String? _currentWebDavProfileId;
  SyncAuditReport? _lastSyncAuditReport;

  DatabaseNotifier(this._ref) : super(const AsyncValue.data(null)) {
    _service.onDirtyChanged = (isDirty) {
      Future.microtask(() {
        _ref.read(isDirtyProvider.notifier).state = isDirty;
      });
    };
  }

  DatabaseService get _service => _ref.read(databaseServiceProvider);

  /// The last sync error, if any. Used by UI to show user-friendly messages.
  Object? get lastSyncError => _lastSyncError;
  SyncAuditReport? get lastSyncAuditReport => _lastSyncAuditReport;

  Future<void> preloadFile(String filePath) => _service.preloadFile(filePath);

  Future<void> openFile(
    String filePath,
    String password, {
    bool isCloud = false,
    String? webDavProfileId,
    String? syncedETag,
    Uint8List? keyData,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.openFile(filePath, password, keyData: keyData);
      String? remotePath;
      String? eTag = syncedETag;
      DateTime? remoteMTime;
      if (isCloud) {
        final config = await _ref
            .read(webDavSettingsServiceProvider)
            .getConfigById(webDavProfileId);
        if (config != null && config.enabled) {
          _currentWebDavProfileId = config.id;
          remotePath = config.remoteFilePath;
          if (syncedETag != null) {
            // Welcome screen already verified eTag, reuse it directly
            _service.setLastSyncedRemoteInfo(RemoteFileInfo(eTag: syncedETag));
          } else {
            final info = await _ref
                .read(syncServiceProvider)
                .getRemoteFileInfo(config);
            _service.setLastSyncedRemoteInfo(info);
            eTag = info?.eTag;
            remoteMTime = info?.mTime;
          }
        }
      } else {
        _currentWebDavProfileId = null;
      }
      final recentSvc = _ref.read(recentFilesServiceProvider);
      await Future.wait([
        recentSvc.addRecentFile(
          filePath,
          isCloud: isCloud,
          remotePath: remotePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: eTag,
          lastSyncedMTime: remoteMTime,
        ),
        recentSvc.setLastOpenedFile(
          filePath,
          isCloud: isCloud,
          remotePath: remotePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: eTag,
          lastSyncedMTime: remoteMTime,
        ),
      ]);
      _ref.read(openedFromCloudProvider.notifier).state = isCloud;
      if (!isCloud) {
        _currentWebDavProfileId = null;
      }
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
      _ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDatabase(
    String name,
    String password,
    String filePath, {
    Uint8List? keyData,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.createDatabase(
        name,
        password,
        filePath,
        keyData: keyData,
      );
      final recentSvc = _ref.read(recentFilesServiceProvider);
      await Future.wait([
        recentSvc.addRecentFile(filePath),
        recentSvc.setLastOpenedFile(filePath),
      ]);
      _ref.read(openedFromCloudProvider.notifier).state = false;
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Saves locally and syncs to WebDAV if enabled.
  /// Returns true on success, false if a conflict was detected (caller should show dialog).
  Future<bool> save() async {
    final wasDirty = _service.isDirty;
    final bytes = await _service.save();
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    // Only sync to cloud if the current database was opened from or created as a cloud database
    if (config != null &&
        config.enabled &&
        _ref.read(openedFromCloudProvider)) {
      _ref.read(syncStateProvider.notifier).state = SyncState.syncing;
      try {
        final syncService = _ref.read(syncServiceProvider);
        // Conflict detection: check if remote changed since last sync
        final remoteInfo = await syncService.getRemoteFileInfo(config);
        final lastInfo = _service.lastSyncedRemoteInfo;
        if (_hasRemoteChanged(remoteInfo, lastInfo)) {
          _lastSyncAuditReport = await inspectCloudDiff();
          _ref.read(syncStateProvider.notifier).state = SyncState.conflict;
          return false;
        }
        // Skip upload if local content hasn't changed since last save
        if (!wasDirty) {
          log.i('Content unchanged, skipping upload');
          _ref.read(syncStateProvider.notifier).state = SyncState.success;
          return true;
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
          final wasCloud = existing.any(
            (f) => f.path == _service.filePath && f.isCloud,
          );
          await Future.wait([
            recentSvc.addRecentFile(
              _service.filePath!,
              isCloud: wasCloud,
              remotePath: config.remoteFilePath,
              webDavProfileId: _currentWebDavProfileId,
              lastSyncedETag: newInfo!.eTag,
              lastSyncedMTime: newInfo.mTime,
            ),
            recentSvc.setLastOpenedFile(
              _service.filePath!,
              isCloud: wasCloud,
              remotePath: config.remoteFilePath,
              webDavProfileId: _currentWebDavProfileId,
              lastSyncedETag: newInfo.eTag,
              lastSyncedMTime: newInfo.mTime,
            ),
          ]);
        }
        _ref.read(syncStateProvider.notifier).state = SyncState.success;
      } catch (e) {
        log.e('Sync failed', error: e);
        _ref.read(syncStateProvider.notifier).state = SyncState.error;
        _lastSyncError = e;
        return false;
      }
    }
    return true;
  }

  /// Force upload, ignoring conflict detection (used after user chooses to overwrite).
  Future<void> forceUpload() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled) return;
    final backupSvc = _ref.read(backupServiceProvider);
    if (_service.filePath != null && await backupSvc.isAutoBackupEnabled()) {
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
      if (newInfo?.eTag != null && _service.filePath != null) {
        final recentSvc = _ref.read(recentFilesServiceProvider);
        await Future.wait([
          recentSvc.addRecentFile(
            _service.filePath!,
            isCloud: true,
            remotePath: config.remoteFilePath,
            webDavProfileId: _currentWebDavProfileId,
            lastSyncedETag: newInfo!.eTag,
            lastSyncedMTime: newInfo.mTime,
          ),
          recentSvc.setLastOpenedFile(
            _service.filePath!,
            isCloud: true,
            remotePath: config.remoteFilePath,
            webDavProfileId: _currentWebDavProfileId,
            lastSyncedETag: newInfo.eTag,
            lastSyncedMTime: newInfo.mTime,
          ),
        ]);
      }
      _ref.read(syncStateProvider.notifier).state = SyncState.success;
      _lastSyncError = null;
      _lastSyncAuditReport = null;
    } catch (e) {
      _lastSyncError = e;
      _ref.read(syncStateProvider.notifier).state = SyncState.error;
    }
  }

  Future<bool> restoreBackupBytes(Uint8List bytes, {String? password}) async {
    final db = await _service.reloadFromBytes(bytes, password: password);
    await _service.save();
    state = AsyncValue.data(db);
    _ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db);

    if (_ref.read(openedFromCloudProvider)) {
      await forceUpload();
      return _ref.read(syncStateProvider) == SyncState.success;
    }

    return true;
  }

  Future<void> saveAs(String newPath) async {
    await _service.saveAs(newPath);
  }

  Future<void> close() async {
    if (_service.isOpen && _service.isDirty) {
      try {
        final success = await save();
        if (!success) {
          log.w(
            'Database saved locally before close, but cloud sync reported a conflict.',
          );
        }
      } catch (e, st) {
        log.e('Failed to save database before close', error: e, stackTrace: st);
      }
    }

    _service.close();
    state = const AsyncValue.data(null);
    _currentWebDavProfileId = null;
    _ref.read(openedFromCloudProvider.notifier).state = false;
    unawaited(_ref.read(recentFilesServiceProvider).clearLastOpenedFile());
    _ref.read(autoLockProvider.notifier).cancelTimer();
    _ref.read(autoSaveProvider.notifier).cancelTimer();
    _ref.read(syncServiceProvider).clearCache();
    _ref.invalidate(recentFilesProvider);
  }

  Future<void> reloadFromCloud() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled) {
      throw Exception('please_configure_webdav');
    }
    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.downloadWithInfo(config);
    if (result == null) throw Exception('cloud_database_not_exist');
    final db = await _service.reloadFromBytes(result.bytes);
    _service.setLastSyncedRemoteInfo(result.info);
    state = AsyncValue.data(db);
    _ref.read(expirationReminderProvider.notifier).checkExpiringEntries(db);
    if (_service.filePath != null) {
      final recentSvc = _ref.read(recentFilesServiceProvider);
      final existing = await recentSvc.getRecentFiles();
      final wasCloud = existing.any(
        (f) => f.path == _service.filePath && f.isCloud,
      );
      await Future.wait([
        recentSvc.addRecentFile(
          _service.filePath!,
          isCloud: wasCloud,
          remotePath: config.remoteFilePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: result.info.eTag,
          lastSyncedMTime: result.info.mTime,
        ),
        recentSvc.setLastOpenedFile(
          _service.filePath!,
          isCloud: wasCloud,
          remotePath: config.remoteFilePath,
          webDavProfileId: _currentWebDavProfileId,
          lastSyncedETag: result.info.eTag,
          lastSyncedMTime: result.info.mTime,
        ),
      ]);
    }
  }

  /// Checks if the remote file has changed since last sync.
  /// Returns true if remote has newer changes (conflict).
  Future<bool> checkRemoteChanges() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled) return false;
    final syncService = _ref.read(syncServiceProvider);
    final remoteInfo = await syncService.getRemoteFileInfo(config);
    final lastInfo = _service.lastSyncedRemoteInfo;
    if (remoteInfo == null || lastInfo == null) return false;
    return _hasRemoteChanged(remoteInfo, lastInfo);
  }

  Future<SyncAuditReport?> inspectCloudDiff() async {
    final config = await _ref
        .read(webDavSettingsServiceProvider)
        .getConfigById(_currentWebDavProfileId);
    if (config == null || !config.enabled || _service.db == null) return null;

    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.downloadWithInfo(config);
    if (result == null) return null;

    final report = await _service.buildSyncAuditReportFromBytes(result.bytes);
    _lastSyncAuditReport = report;
    return report;
  }

  bool _hasRemoteChanged(RemoteFileInfo? remoteInfo, RemoteFileInfo? lastInfo) {
    if (remoteInfo == null || lastInfo == null) return false;
    if (remoteInfo.eTag != null && lastInfo.eTag != null) {
      return remoteInfo.eTag != lastInfo.eTag;
    }
    if (remoteInfo.mTime != null && lastInfo.mTime != null) {
      return remoteInfo.mTime != lastInfo.mTime;
    }
    return false;
  }

  Future<void> changePassword(
    String oldPassword,
    String newPassword, {
    bool updateKeyFile = false,
    Uint8List? newKeyData,
  }) async {
    _service.changePassword(
      oldPassword,
      newPassword,
      updateKeyFile: updateKeyFile,
      newKeyData: newKeyData,
    );
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

final cloudOfflineModeProvider = StateProvider<bool>((ref) => false);

final cloudOfflineReasonProvider = StateProvider<String?>((ref) => null);

/// Whether the database has unsaved changes.
final isDirtyProvider = StateProvider<bool>((ref) => false);
