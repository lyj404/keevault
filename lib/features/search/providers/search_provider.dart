import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../database/providers/database_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Incremented by [refreshExplorerLists] whenever entries are mutated.
/// The search provider watches this to invalidate stale results.
final entryVersionProvider = StateProvider<int>((ref) => 0);

final searchResultsProvider = Provider<List<KdbxEntry>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  // Watch the version counter so search results refresh after mutations
  ref.watch(entryVersionProvider);
  final service = ref.watch(databaseServiceProvider);
  return service.search(query);
});
