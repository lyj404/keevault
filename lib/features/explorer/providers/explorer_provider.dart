import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../database/providers/database_provider.dart';

final currentGroupPathProvider = StateProvider<String>((ref) => '');

final currentGroupProvider = Provider<KdbxGroup?>((ref) {
  final db = ref.watch(databaseProvider).valueOrNull;
  if (db == null) return null;
  final path = ref.watch(currentGroupPathProvider);
  final service = ref.read(databaseServiceProvider);
  return service.findGroupByPath(path) ?? db.root;
});

final entriesProvider = StateProvider<List<KdbxEntry>>((ref) {
  final group = ref.watch(currentGroupProvider);
  return [...?group?.entries];
});

/// Currently selected entry in the explorer (for keyboard shortcuts).
final selectedEntryProvider = StateProvider<KdbxEntry?>((ref) => null);

/// Call after any mutation (add/delete/edit) to refresh the entry list.
void refreshExplorerLists(WidgetRef ref) {
  final group = ref.read(currentGroupProvider);
  ref.read(entriesProvider.notifier).state = [...?group?.entries];
  ref.read(selectedEntryProvider.notifier).state = null;
}

final breadcrumbProvider = Provider<List<String>>((ref) {
  final path = ref.watch(currentGroupPathProvider);
  if (path.isEmpty) return ['Root'];
  return ['Root', ...path.split('/')];
});
