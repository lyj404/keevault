import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../data/database_service.dart';
import '../data/recent_files_service.dart';

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

  Future<void> openFile(String filePath, String password) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.openFile(filePath, password);
      await _ref.read(recentFilesServiceProvider).addRecentFile(filePath);
      state = AsyncValue.data(db);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createDatabase(String name, String password, String filePath) async {
    state = const AsyncValue.loading();
    try {
      final db = await _service.createDatabase(name, password, filePath);
      await _ref.read(recentFilesServiceProvider).addRecentFile(filePath);
      state = AsyncValue.data(db);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> save() async {
    await _service.save();
  }

  Future<void> saveAs(String newPath) async {
    await _service.saveAs(newPath);
  }

  void close() {
    _service.close();
    state = const AsyncValue.data(null);
  }

  void markDirty() => _service.markDirty();
  bool get isDirty => _service.isDirty;
}

final recentFilesProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(recentFilesServiceProvider).getRecentFiles();
});
