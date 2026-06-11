import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';

class RecentFile {
  final String path;
  final bool isCloud;
  final String? remotePath;

  const RecentFile({required this.path, this.isCloud = false, this.remotePath});

  Map<String, dynamic> toJson() => {
        'path': path,
        'isCloud': isCloud,
        if (remotePath != null) 'remotePath': remotePath,
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String? ?? '',
        isCloud: json['isCloud'] as bool? ?? false,
        remotePath: json['remotePath'] as String?,
      );
}

class LastOpenedFile {
  final String path;
  final bool isCloud;
  final String? remotePath;

  const LastOpenedFile({required this.path, this.isCloud = false, this.remotePath});

  Map<String, dynamic> toJson() => {
        'path': path,
        'isCloud': isCloud,
        if (remotePath != null) 'remotePath': remotePath,
      };

  factory LastOpenedFile.fromJson(Map<String, dynamic> json) => LastOpenedFile(
        path: json['path'] as String? ?? '',
        isCloud: json['isCloud'] as bool? ?? false,
        remotePath: json['remotePath'] as String?,
      );
}

class RecentFilesService {
  static const _key = 'recent_files';
  static const _lastOpenedKey = 'last_opened_file';
  final _storage = const FlutterSecureStorage();

  Future<List<RecentFile>> getRecentFiles() async {
    final data = await _storage.read(key: _key);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.map((e) {
        if (e is String) return RecentFile(path: e);
        return RecentFile.fromJson(e as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentFile(String filePath, {bool isCloud = false, String? remotePath}) async {
    final files = await getRecentFiles();
    files.removeWhere((f) => f.path == filePath);
    files.insert(0, RecentFile(path: filePath, isCloud: isCloud, remotePath: remotePath));
    if (files.length > AppConstants.maxRecentFiles) {
      files.removeRange(AppConstants.maxRecentFiles, files.length);
    }
    await _storage.write(
      key: _key,
      value: jsonEncode(files.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> removeRecentFile(String filePath) async {
    final files = await getRecentFiles();
    files.removeWhere((f) => f.path == filePath);
    await _storage.write(
      key: _key,
      value: jsonEncode(files.map((f) => f.toJson()).toList()),
    );
  }

  Future<LastOpenedFile?> getLastOpenedFile() async {
    final data = await _storage.read(key: _lastOpenedKey);
    if (data == null) return null;
    try {
      return LastOpenedFile.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setLastOpenedFile(String filePath, {bool isCloud = false, String? remotePath}) async {
    await _storage.write(
      key: _lastOpenedKey,
      value: jsonEncode(LastOpenedFile(path: filePath, isCloud: isCloud, remotePath: remotePath).toJson()),
    );
  }

  Future<void> clearLastOpenedFile() async {
    await _storage.delete(key: _lastOpenedKey);
  }
}
