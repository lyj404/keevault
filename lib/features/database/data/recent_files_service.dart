import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';

class RecentFilesService {
  static const _key = 'recent_files';
  final _storage = const FlutterSecureStorage();

  Future<List<String>> getRecentFiles() async {
    final data = await _storage.read(key: _key);
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecentFile(String filePath) async {
    final files = await getRecentFiles();
    files.remove(filePath);
    files.insert(0, filePath);
    if (files.length > AppConstants.maxRecentFiles) {
      files.removeRange(AppConstants.maxRecentFiles, files.length);
    }
    await _storage.write(key: _key, value: jsonEncode(files));
  }

  Future<void> removeRecentFile(String filePath) async {
    final files = await getRecentFiles();
    files.remove(filePath);
    await _storage.write(key: _key, value: jsonEncode(files));
  }
}
