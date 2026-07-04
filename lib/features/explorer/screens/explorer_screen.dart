import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/move_to_group_dialog.dart';
import '../../../core/widgets/attachments_section.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../../sync/data/sync_service.dart' show SyncException, SyncErrorType;
import '../../totp/data/totp_service.dart';
import '../../totp/widgets/totp_edit_sheet.dart';
import '../../search/providers/search_provider.dart';
import '../providers/explorer_provider.dart';
part 'explorer_layouts.dart';
part 'explorer_group_tree.dart';
part 'explorer_lists.dart';
part 'explorer_sheets.dart';
part 'explorer_bottom_bars.dart';


class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(databaseProvider);

    return dbAsync.when(
      data: (db) {
        if (db == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/welcome');
          });
          return const SizedBox.shrink();
        }
        return const _ExplorerBody();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
      error: (e, _) => Scaffold(body: Center(child: Text(AppLocalizations.of(context)!.error(e.toString())))),
    );
  }
}

class _ExplorerBody extends ConsumerStatefulWidget {
  const _ExplorerBody();

  @override
  ConsumerState<_ExplorerBody> createState() => _ExplorerBodyState();
}

class _ExplorerBodyState extends ConsumerState<_ExplorerBody> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRemoteChangesOnResume();
    }
  }

  Future<void> _checkRemoteChangesOnResume() async {
    final isOpenedFromCloud = ref.read(openedFromCloudProvider);
    if (!isOpenedFromCloud) return;
    final hasChanges = await ref.read(databaseProvider.notifier).checkRemoteChanges();
    if (hasChanges && mounted) {
      _showAutoSyncDialog();
    }
  }

  void _showAutoSyncDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cloudNewVersion),
        content: Text(l10n.cloudModifiedSyncLatest),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.ignore),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncFromCloud(context);
            },
            child: Text(l10n.sync),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final entries = ref.watch(entriesProvider);
    final breadcrumbs = ref.watch(breadcrumbProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final service = ref.read(databaseServiceProvider);
    final isRecycleBin = _isInRecycleBin(currentGroup);
    final isOpenedFromCloud = ref.watch(openedFromCloudProvider);
    final isDirty = ref.watch(isDirtyProvider);
    final selectedEntry = ref.watch(selectedEntryProvider);
    final isMultiSelect = ref.watch(isMultiSelectModeProvider);
    final selectedEntries = ref.watch(selectedEntriesProvider);
    final sortOption = ref.watch(entrySortOptionProvider);

    void onEntrySelect(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      ref.read(activeEntryProvider.notifier).state = entry;
    }

    void onEntryOpen(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      ref.read(activeEntryProvider.notifier).state = entry;
      final path = currentGroup != null ? service.getGroupPath(currentGroup) : '';
      final encodedUuid = Uri.encodeComponent(entry.uuid.string);
      log.d('[Explorer] onEntryOpen uuid=${entry.uuid.string} groupPath="$path" entryParent=${entry.parent?.name}');
      context.push('/entry/detail?uuid=$encodedUuid&groupPath=${Uri.encodeComponent(path)}');
    }

    if (isWide) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final pop = _popPath(ref);
          if (pop != null) {
            pop();
          } else {
            context.go('/welcome');
          }
        },
        child: _WideLayout(
          breadcrumbs: breadcrumbs,
          currentGroup: currentGroup,
          entries: entries,
          selectedEntry: selectedEntry,
          isRecycleBin: isRecycleBin,
          isOpenedFromCloud: isOpenedFromCloud,
          isDirty: isDirty,
          onGroupTap: (group) {
            ref.read(selectedEntryProvider.notifier).state = null;
            ref.read(activeEntryProvider.notifier).state = null;
            final path = service.getGroupPath(group);
            ref.read(currentGroupPathProvider.notifier).state = path;
          },
          onEntrySelect: onEntrySelect,
          onEntryOpen: onEntryOpen,
          onDeleteEntry: isRecycleBin
              ? (entry) => _permanentDeleteEntry(context, ref, entry)
              : (entry) => _deleteEntry(context, ref, entry),
          onRestoreEntry: isRecycleBin ? (entry) => _restoreEntry(context, ref, entry) : null,
          onMoveEntry: isRecycleBin ? null : (entry) => _moveEntry(context, ref, entry, currentGroup!),
          onDeleteGroup: isRecycleBin ? null : (group) => _deleteGroup(context, ref, group),
          onRenameGroup: isRecycleBin ? null : (group) => _renameGroup(context, ref, group),
          onRestoreGroup: isRecycleBin ? (group) => _restoreGroup(context, ref, group) : null,
          onPermanentDeleteGroup: isRecycleBin ? (group) => _permanentDeleteGroup(context, ref, group) : null,
          onAddEntry: isRecycleBin ? null : () => _showAddEntrySheet(context, ref, currentGroup!),
          onAddGroup: isRecycleBin ? null : () => _showAddGroupSheet(context, ref, currentGroup!),
          onSave: () => _save(context, ref),
          onClose: () => _close(context, ref),
          onSearch: () => context.push('/search'),
          onPop: _popPath(ref),
          onImportCsv: () => _importCsv(context, ref),
          onExportCsv: () => _exportCsv(context, ref),
          onExportKdbx: () => _exportKdbx(context, ref),
          sortOption: sortOption,
          onSortChanged: _onSortChanged,
          isMultiSelect: isMultiSelect,
          selectedEntries: selectedEntries,
          onToggleMultiSelect: _toggleMultiSelect,
          onToggleEntrySelection: _toggleEntrySelection,
          onSelectAll: () => _selectAllEntries(entries),
          onCancelSelection: _cancelSelection,
          onBatchDelete: () => _batchDelete(context, ref),
          onBatchMove: () => _batchMove(context, ref),
          onBatchTag: () => _batchTag(context, ref),
          onEntryDropped: isRecycleBin ? null : (entry, target) {
            if (entry.parent == target) return;
            ref.read(databaseServiceProvider).moveItem(entry, target);
            refreshExplorerLists(ref);
            if (context.mounted) {
              showToast(context, AppLocalizations.of(context)!.moved);
            }
          },
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final pop = _popPath(ref);
        if (pop != null) {
          pop();
        } else {
          context.go('/welcome');
        }
      },
      child: _NarrowLayout(
        breadcrumbs: breadcrumbs,
        currentGroup: currentGroup,
        entries: entries,
        selectedEntry: selectedEntry,
        isRecycleBin: isRecycleBin,
        isOpenedFromCloud: isOpenedFromCloud,
        isDirty: isDirty,
        onGroupTap: (group) {
          ref.read(selectedEntryProvider.notifier).state = null;
          ref.read(activeEntryProvider.notifier).state = null;
          final path = service.getGroupPath(group);
          ref.read(currentGroupPathProvider.notifier).state = path;
        },
        onEntrySelect: onEntrySelect,
        onEntryOpen: onEntryOpen,
        onDeleteEntry: isRecycleBin
            ? (entry) => _permanentDeleteEntry(context, ref, entry)
            : (entry) => _deleteEntry(context, ref, entry),
        onRestoreEntry: isRecycleBin ? (entry) => _restoreEntry(context, ref, entry) : null,
        onMoveEntry: isRecycleBin ? null : (entry) => _moveEntry(context, ref, entry, currentGroup!),
        onDeleteGroup: isRecycleBin ? null : (group) => _deleteGroup(context, ref, group),
        onRenameGroup: isRecycleBin ? null : (group) => _renameGroup(context, ref, group),
        onRestoreGroup: isRecycleBin ? (group) => _restoreGroup(context, ref, group) : null,
        onPermanentDeleteGroup: isRecycleBin ? (group) => _permanentDeleteGroup(context, ref, group) : null,
        onAddEntry: isRecycleBin ? null : () => _showAddEntrySheet(context, ref, currentGroup!),
        onAddGroup: isRecycleBin ? null : () => _showAddGroupSheet(context, ref, currentGroup!),
        onSave: () => _save(context, ref),
        onClose: () => _close(context, ref),
        onSearch: () => context.push('/search'),
        onPop: _popPath(ref),
        onImportCsv: () => _importCsv(context, ref),
        onExportCsv: () => _exportCsv(context, ref),
        onExportKdbx: () => _exportKdbx(context, ref),
        sortOption: sortOption,
        onSortChanged: _onSortChanged,
        isMultiSelect: isMultiSelect,
        selectedEntries: selectedEntries,
        onToggleMultiSelect: _toggleMultiSelect,
        onToggleEntrySelection: _toggleEntrySelection,
        onSelectAll: () => _selectAllEntries(entries),
        onCancelSelection: _cancelSelection,
        onBatchDelete: () => _batchDelete(context, ref),
        onBatchMove: () => _batchMove(context, ref),
        onBatchTag: () => _batchTag(context, ref),
      ),
    );
  }

  void _deleteEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEntry),
        content: Text(l10n.moveToRecycleBin),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ref.read(databaseServiceProvider).deleteItem(entry);
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, l10n.movedToRecycleBin);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _permanentDeleteEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permanentDelete),
        content: Text(l10n.permanentDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              final db = ref.read(databaseServiceProvider).db;
              if (db != null) {
                db.move(item: entry, target: null);
                ref.read(databaseServiceProvider).markDirty();
              }
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, l10n.permanentlyDeleted);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _restoreEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    final service = ref.read(databaseServiceProvider);
    final success = service.restoreItem(entry);
    final l10n = AppLocalizations.of(context)!;
    if (success) {
      refreshExplorerLists(ref);
      showToast(context, l10n.restored);
    } else {
      showToast(context, l10n.restoreFailed, isError: true);
    }
  }

  void _restoreGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final service = ref.read(databaseServiceProvider);
    final success = service.restoreItem(group);
    final l10n = AppLocalizations.of(context)!;
    if (success) {
      refreshExplorerLists(ref);
      showToast(context, l10n.restored);
    } else {
      showToast(context, l10n.restoreFailed, isError: true);
    }
  }

  void _permanentDeleteGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.permanentDelete),
        content: Text(l10n.permanentDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              final db = ref.read(databaseServiceProvider).db;
              if (db != null) {
                db.move(item: group, target: null);
                ref.read(databaseServiceProvider).markDirty();
              }
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, l10n.permanentlyDeleted);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _moveEntry(BuildContext context, WidgetRef ref, KdbxEntry entry, KdbxGroup currentGroup) async {
    final db = ref.read(databaseServiceProvider).db;
    if (db == null) return;
    final target = await showMoveToGroupDialog(context, db: db, excludeGroup: currentGroup);
    if (target == null) return;
    ref.read(databaseServiceProvider).moveItem(entry, target);
    refreshExplorerLists(ref);
    if (context.mounted) {
      showToast(context, AppLocalizations.of(context)!.moved);
    }
  }

  void _deleteGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final l10n = AppLocalizations.of(context)!;
    if (group.entries.isNotEmpty || group.groups.isNotEmpty) {
      showToast(context, l10n.cannotDeleteNonEmptyGroup, isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(l10n.deleteGroupConfirm(group.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              ref.read(databaseServiceProvider).deleteItem(group);
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, l10n.movedToRecycleBin);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _renameGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameGroup),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.groupName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              group.name = newName;
              ref.read(databaseServiceProvider).markDirty();
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  bool _isInRecycleBin(KdbxGroup? group) {
    KdbxGroup? current = group;
    while (current != null) {
      if (current.icon == KdbxIcon.trashBin) return true;
      current = current.parent;
    }
    return false;
  }

  VoidCallback? _popPath(WidgetRef ref) {
    final breadcrumbs = ref.read(breadcrumbProvider);
    if (breadcrumbs.length <= 1) return null;
    return () {
      final current = ref.read(currentGroupPathProvider);
      final parts = current.split('/')..removeLast();
      ref.read(currentGroupPathProvider.notifier).state = parts.join('/');
    };
  }

  void _save(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.read(databaseProvider.notifier).save().then((success) {
      if (!context.mounted) return;
      if (success) {
        showToast(context, l10n.saved);
      } else {
        _showConflictDialog(context, ref);
      }
    });
  }

  void _showConflictDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.syncConflict),
        content: Text(l10n.syncConflictMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncFromCloud(context);
            },
            child: Text(l10n.downloadCloudVersion),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _forceUpload(context, ref);
            },
            child: Text(l10n.overwriteCloud),
          ),
        ],
      ),
    );
  }

  void _forceUpload(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.read(databaseProvider.notifier).forceUpload().then((_) {
      if (context.mounted) {
        final syncState = ref.read(syncStateProvider);
        if (syncState == SyncState.success) {
          showToast(context, l10n.overwrittenToCloud);
        } else if (syncState == SyncState.error) {
          showToast(context, l10n.syncFailed, isError: true);
        }
      }
    });
  }

  void _close(BuildContext context, WidgetRef ref) {
    ref.read(databaseProvider.notifier).close();
    if (context.mounted) context.go('/welcome');
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null) return;

    try {
      final file = result.files.single;
      final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) {
        if (context.mounted) showToast(context, l10n.importFailed('No file data'), isError: true);
        return;
      }

      // Try UTF-8 first, fall back to system encoding (handles GBK/ANSI on Chinese Windows)
      String content = utf8.decode(bytes, allowMalformed: true);
      // If UTF-8 decoding produced no line breaks (corrupted encoding), retry with system encoding
      if (!content.contains('\n') && bytes.length > 10) {
        final alt = systemEncoding.decode(bytes);
        if (alt.contains('\n')) {
          log.i('CSV import: UTF-8 produced no line breaks, using system encoding');
          content = alt;
        }
      }

      log.i('CSV import: file = ${file.name}, bytes = ${bytes.length}');
      log.i('CSV import: content length = ${content.length}, line count = ${content.split('\n').length}');
      final csvService = ref.read(csvServiceProvider);
      final entries = csvService.importFromCsv(content);
      if (entries.isEmpty) {
        if (context.mounted) showToast(context, l10n.noEntriesInCsv, isError: true);
        return;
      }

      final dbService = ref.read(databaseServiceProvider);
      final db = dbService.db;
      if (db == null) {
        if (context.mounted) showToast(context, l10n.importFailed('Database not open'), isError: true);
        return;
      }
      final groupPath = ref.read(currentGroupPathProvider);
      final targetGroup = dbService.findGroupByPath(groupPath) ?? db.root;

      final count = csvService.createEntries(entries, db, targetGroup);
      dbService.markDirty();
      dbService.rebuildEntryCache();
      refreshExplorerLists(ref);

      if (context.mounted) {
        showToast(context, l10n.importSuccess(count));
      }
    } catch (e) {
      if (context.mounted) {
        showToast(context, l10n.importFailed(e.toString()), isError: true);
      }
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final dbService = ref.read(databaseServiceProvider);
    final entries = dbService.allEntries;
    if (entries.isEmpty) {
      if (context.mounted) showToast(context, l10n.noEntriesToExport, isError: true);
      return;
    }

    final csvService = ref.read(csvServiceProvider);
    final csvContent = csvService.exportToCsv(entries);

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportCsv,
      fileName: 'passwords.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (savePath == null) return;

    try {
      final file = File(savePath);
      await file.writeAsString(csvContent, encoding: utf8);
      if (context.mounted) showToast(context, l10n.exportSuccess);
    } catch (e) {
      if (context.mounted) showToast(context, l10n.exportFailed, isError: true);
    }
  }

  Future<void> _exportKdbx(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final dbService = ref.read(databaseServiceProvider);
    if (dbService.db == null) return;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.exportKdbx,
      fileName: 'database.kdbx',
      type: FileType.custom,
      allowedExtensions: ['kdbx'],
    );
    if (savePath == null) return;

    try {
      final bytes = await dbService.saveToBytes();
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      if (context.mounted) showToast(context, l10n.exportSuccess);
    } catch (e) {
      if (context.mounted) showToast(context, l10n.exportFailed, isError: true);
    }
  }

  void _showAddEntrySheet(BuildContext context, WidgetRef ref, KdbxGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddEntrySheet(group: group),
    );
  }

  // Sort and batch operations
  void _onSortChanged(EntrySortOption option) {
    ref.read(entrySortOptionProvider.notifier).state = option;
  }

  void _toggleMultiSelect() {
    final isMulti = ref.read(isMultiSelectModeProvider);
    ref.read(isMultiSelectModeProvider.notifier).state = !isMulti;
    if (isMulti) {
      ref.read(selectedEntriesProvider.notifier).state = {};
    }
  }

  void _toggleEntrySelection(KdbxEntry entry) {
    final selected = ref.read(selectedEntriesProvider);
    final newSet = {...selected};
    if (newSet.contains(entry)) {
      newSet.remove(entry);
    } else {
      newSet.add(entry);
    }
    ref.read(selectedEntriesProvider.notifier).state = newSet;
  }

  void _selectAllEntries(List<KdbxEntry> entries) {
    ref.read(selectedEntriesProvider.notifier).state = {...entries};
  }

  void _cancelSelection() {
    ref.read(isMultiSelectModeProvider.notifier).state = false;
    ref.read(selectedEntriesProvider.notifier).state = {};
  }

  Future<void> _batchDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.read(selectedEntriesProvider);
    if (selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batchDelete),
        content: Text(l10n.batchDeleteConfirm(selected.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final service = ref.read(databaseServiceProvider);
    for (final entry in selected) {
      service.deleteItem(entry);
    }
    _cancelSelection();
    refreshExplorerLists(ref);
    if (context.mounted) showToast(context, l10n.movedToRecycleBin);
  }

  Future<void> _batchMove(BuildContext context, WidgetRef ref) async {
    final selected = ref.read(selectedEntriesProvider);
    if (selected.isEmpty) return;
    final service = ref.read(databaseServiceProvider);
    final db = ref.read(databaseProvider).valueOrNull;
    if (db == null) return;
    final currentGroup = ref.read(currentGroupProvider);
    final target = await showMoveToGroupDialog(context, db: db, excludeGroup: currentGroup);
    if (target == null) return;
    for (final entry in selected) {
      service.moveItem(entry, target);
    }
    _cancelSelection();
    refreshExplorerLists(ref);
  }

  Future<void> _batchTag(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.read(selectedEntriesProvider);
    if (selected.isEmpty) return;
    final tagController = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.batchTagTitle),
        content: TextField(
          controller: tagController,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.batchTagHint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, tagController.text.trim()), child: Text(l10n.confirm)),
        ],
      ),
    );
    tagController.dispose();
    if (tag == null || tag.isEmpty) return;
    for (final entry in selected) {
      final tags = entry.tags ?? [];
      if (!tags.contains(tag)) {
        entry.tags = [...tags, tag];
      }
    }
    ref.read(databaseServiceProvider).markDirty();
    _cancelSelection();
    refreshExplorerLists(ref);
  }
  void _showAddGroupSheet(BuildContext context, WidgetRef ref, KdbxGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddGroupSheet(group: group),
    );
  }
}

