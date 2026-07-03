import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/providers/database_provider.dart';
import '../../database/data/database_service.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = Provider<List<SearchResult>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return [];
  final service = ref.watch(databaseServiceProvider);
  return service.search(query);
});