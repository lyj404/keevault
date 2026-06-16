import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../data/database_service.dart';
import '../data/recent_files_service.dart';
export '../data/recent_files_service.dart' show RecentFile;
import '../../../core/providers/auto_lock_provider.dart';
import '../../backup/providers/backup_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/data/sync_service.dart' show RemoteFileInfo;
import '../../sync/providers/sync_provider.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final recentFilesServiceProvider = Provider<RecentFilesService>((ref) {
  return RecentFilesService();
});

final databaseProvider = StateNotifierProvider<DatabaseNotifier, AsyncValue<KdbxDatabase?>>((ref) {
  return DatabaseNotifier(ref);
});

class DatabaseNotifier extends StateNotifier<AsyncValue<KdbxDatabase?>> {
  final Ref _ref;

  DatabaseNotifier(this._ref) : super(const AsyncValue.data(null));

  DatabaseService get _service => _ref.read(databaseServiceProvider);

  Future<void> preloadFile(String filePath) => _service.preloadFile(filePath);

  Future<void> openFile(String filePath, String password, {bool isCloud = false, String? syncedETag}) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.openFile(filePath, password);
      String? remotePath;
      String? eTag = syncedETag;
      if (isCloud) {
        final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
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
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDatabase(String name, String password, String filePath) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.createDatabase(name, password, filePath);
      final recentSvc = _ref.read(recentFilesServiceProvider);
      await Future.wait([
        recentSvc.addRecentFile(filePath),
        recentSvc.setLastOpenedFile(filePath),
      ]);
      state = AsyncValue.data(db);
      _ref.read(autoLockProvider.notifier).resetTimer();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Saves locally and syncs to WebDAV if enabled.
  /// Returns true on success, false if a conflict was detected (caller should show dialog).
  Future<bool> save() async {
    final bytes = await _service.save();
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
    if (config != null && config.enabled) {
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
          return false;
        }
        await syncService.ensureRemoteDirectory(config);
        await syncService.uploadDatabase(config, bytes);
        // Store the remote metadata after successful upload
        final newInfo = await syncService.getRemoteFileInfo(config);
        _service.setLastSyncedRemoteInfo(newInfo);
        // Persist the eTag so next startup can skip redundant download
        if (newInfo?.eTag != null && _service.filePath != null) {
          final recentSvc = _ref.read(recentFilesServiceProvider);
          await Future.wait([
            recentSvc.addRecentFile(_service.filePath!, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: newInfo!.eTag),
            recentSvc.setLastOpenedFile(_service.filePath!, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: newInfo.eTag),
          ]);
        }
        _ref.read(syncStateProvider.notifier).state = SyncState.success;
      } catch (e) {
        _ref.read(syncStateProvider.notifier).state = SyncState.error;
      }
    }
    return true;
  }

  /// Force upload, ignoring conflict detection (used after user chooses to overwrite).
  Future<void> forceUpload() async {
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
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
    _ref.read(recentFilesServiceProvider).clearLastOpenedFile();
    _ref.read(autoLockProvider.notifier).cancelTimer();
  }

  Future<void> reloadFromCloud() async {
    final config = await _ref.read(webDavSettingsServiceProvider).getConfig();
    if (config == null || !config.enabled) throw Exception('please_configure_webdav');
    final syncService = _ref.read(syncServiceProvider);
    final result = await syncService.downloadWithInfo(config);
    if (result == null) throw Exception('cloud_database_not_exist');
    final db = await _service.reloadFromBytes(result.bytes);
    _service.setLastSyncedRemoteInfo(result.info);
    state = AsyncValue.data(db);
    if (_service.filePath != null) {
      final recentSvc = _ref.read(recentFilesServiceProvider);
      await Future.wait([
        recentSvc.addRecentFile(_service.filePath!, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: result.info.eTag),
        recentSvc.setLastOpenedFile(_service.filePath!, isCloud: true, remotePath: config.remoteFilePath, lastSyncedETag: result.info.eTag),
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

  void markDirty() => _service.markDirty();
  bool get isDirty => _service.isDirty;
}

final recentFilesProvider = FutureProvider<List<RecentFile>>((ref) async {
  return ref.read(recentFilesServiceProvider).getRecentFiles();
});

/// Whether the current database was opened from WebDAV (cloud).
final openedFromCloudProvider = StateProvider<bool>((ref) => false);
