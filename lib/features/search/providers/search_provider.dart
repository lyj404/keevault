import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/providers/database_provider.dart';
import '../../database/data/database_service.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Maximum number of ranked search results retained. Keeps the working set
/// bounded for very large vaults; the full list is only materialised when the
/// user scrolls further (re-query with a more specific term).
const searchResultLimit = 200;

final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final service = ref.watch(databaseServiceProvider);
  return service.search(query, limit: searchResultLimit);
});