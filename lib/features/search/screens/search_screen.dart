import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../providers/search_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  KdbxEntry? _selectedEntry;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final service = ref.read(databaseServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: TextStyle(fontSize: 15, color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: l10n.searchEntries,
            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 15),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: colorScheme.onSurfaceVariant),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(AppConstants.searchDebounceDelay, () {
              ref.read(searchQueryProvider.notifier).state = v;
            });
          },
        ),
      ),
      body: _searchCtrl.text.isEmpty
          ? EmptyState(icon: Icons.search_rounded, message: l10n.enterKeywords)
          : results.isEmpty
              ? EmptyState(icon: Icons.search_off_rounded, message: l10n.noResults)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  itemBuilder: (ctx, i) {
                    final entry = results[i];
                    final groupPath = entry.parent != null ? service.getGroupPath(entry.parent!) : '';
                    return RepaintBoundary(
                      child: EntryListTile(
                        key: ValueKey(entry.uuid),
                        entry: entry,
                        isSelected: entry == _selectedEntry,
                        onTap: () {
                          setState(() => _selectedEntry = entry);
                          ref.read(activeEntryProvider.notifier).state = entry;
                        },
                        onOpen: () {
                          final idx = entry.parent?.entries.indexOf(entry) ?? 0;
                          context.push('/entry/detail?index=$idx&groupPath=${Uri.encodeComponent(groupPath)}');
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
