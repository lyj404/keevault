import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';

class RecentFile {
  final String path;
  final bool isCloud;

  const RecentFile({required this.path, this.isCloud = false});

  Map<String, dynamic> toJson() => {'path': path, 'isCloud': isCloud};

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String? ?? '',
        isCloud: json['isCloud'] as bool? ?? false,
      );
}

class RecentFilesService {
  static const _key = 'recent_files';
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

  Future<void> addRecentFile(String filePath, {bool isCloud = false}) async {
    final files = await getRecentFiles();
    files.removeWhere((f) => f.path == filePath);
    files.insert(0, RecentFile(path: filePath, isCloud: isCloud));
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
}
