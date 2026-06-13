import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/logger.dart';

class BackupInfo {
  final String filename;
  final DateTime timestamp;
  final int sizeBytes;
  final String? sourcePath;

  BackupInfo({
    required this.filename,
    required this.timestamp,
    required this.sizeBytes,
    this.sourcePath,
  });
}

class BackupService {
  static const _retentionKey = 'backup_retention_count';
  static const _autoBackupKey = 'backup_auto_enabled';
  static const _defaultRetention = 5;
  final _storage = const FlutterSecureStorage();

  Future<bool> isAutoBackupEnabled() async {
    final val = await _storage.read(key: _autoBackupKey);
    return val == null || val == 'true';
  }

  Future<void> setAutoBackupEnabled(bool enabled) async {
    await _storage.write(key: _autoBackupKey, value: enabled.toString());
  }

  Future<Directory> _backupDir() async {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory('${appDir.path}/backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<int> getRetentionCount() async {
    final val = await _storage.read(key: _retentionKey);
    return val != null ? int.tryParse(val) ?? _defaultRetention : _defaultRetention;
  }

  Future<void> setRetentionCount(int count) async {
    await _storage.write(key: _retentionKey, value: count.toString());
  }

  Future<BackupInfo?> createBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      final dir = await _backupDir();
      final now = DateTime.now();
      final ts = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final dbName = filePath.split(Platform.pathSeparator).last.replaceAll('.kdbx', '');
      final filename = '${dbName}_$ts.kdbx';
      final backupFile = File('${dir.path}/$filename');
      await backupFile.writeAsBytes(bytes);
      log.i('Backup created: $filename (${bytes.length} bytes)');
      await _cleanupOldBackups();
      return BackupInfo(
        filename: filename,
        timestamp: now,
        sizeBytes: bytes.length,
        sourcePath: filePath,
      );
    } catch (e) {
      log.e('Backup failed: $e');
      return null;
    }
  }

  Future<List<BackupInfo>> listBackups() async {
    final dir = await _backupDir();
    final files = await dir.list().where((f) => f.path.endsWith('.kdbx')).toList();
    final backups = <BackupInfo>[];
    for (final f in files) {
      final stat = await f.stat();
      final name = f.path.split(Platform.pathSeparator).last;
      backups.add(BackupInfo(
        filename: name,
        timestamp: stat.modified,
        sizeBytes: stat.size,
      ));
    }
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  Future<String?> getBackupPath(String filename) async {
    final dir = await _backupDir();
    final file = File('${dir.path}/$filename');
    return await file.exists() ? file.path : null;
  }

  Future<bool> deleteBackup(String filename) async {
    try {
      final dir = await _backupDir();
      final file = File('${dir.path}/$filename');
      if (await file.exists()) {
        await file.delete();
        log.i('Backup deleted: $filename');
        return true;
      }
      return false;
    } catch (e) {
      log.e('Delete backup failed: $e');
      return false;
    }
  }

  Future<void> _cleanupOldBackups() async {
    final retention = await getRetentionCount();
    final backups = await listBackups();
    if (backups.length <= retention) return;
    final toRemove = backups.sublist(retention);
    for (final b in toRemove) {
      await deleteBackup(b.filename);
    }
  }
}
