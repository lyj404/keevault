import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
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
import '../providers/explorer_provider.dart';

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

    void onEntrySelect(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      ref.read(activeEntryProvider.notifier).state = entry;
    }

    void onEntryOpen(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      ref.read(activeEntryProvider.notifier).state = entry;
      final path = currentGroup != null ? service.getGroupPath(currentGroup) : '';
      context.push('/entry/detail?uuid=${entry.uuid.string}&groupPath=${Uri.encodeComponent(path)}');
    }

    if (isWide) {
      return _WideLayout(
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
        );
    }

    return _NarrowLayout(
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

  void _showAddGroupSheet(BuildContext context, WidgetRef ref, KdbxGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddGroupSheet(group: group),
    );
  }
}

// ─── Wide layout (desktop/tablet) ────────────────────────────────────────

class _WideLayout extends StatelessWidget {
  final List<String> breadcrumbs;
  final KdbxGroup? currentGroup;
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final bool isRecycleBin;
  final bool isOpenedFromCloud;
  final bool isDirty;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;
  final ValueChanged<KdbxGroup>? onDeleteGroup;
  final ValueChanged<KdbxGroup>? onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;
  final VoidCallback? onAddEntry;
  final VoidCallback? onAddGroup;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback? onPop;
  final VoidCallback? onImportCsv;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportKdbx;

  const _WideLayout({
    required this.breadcrumbs,
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.isRecycleBin,
    required this.isOpenedFromCloud,
    required this.isDirty,
    required this.onGroupTap,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.onDeleteGroup,
    this.onRenameGroup,
    this.onRestoreGroup,
    this.onPermanentDeleteGroup,
    this.onAddEntry,
    this.onAddGroup,
    required this.onSave,
    required this.onClose,
    required this.onSearch,
    this.onPop,
    this.onImportCsv,
    this.onExportCsv,
    this.onExportKdbx,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? ClayColors.surfaceDark : ClayColors.surfaceLight,
      body: Row(
        children: [
          // Sidebar with clay feel
          Container(
            width: 272,
            decoration: BoxDecoration(
              color: isDark ? ClayColors.surfaceCardDark : ClayColors.surfaceCardLight,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFF5EEAD4)).withValues(alpha: isDark ? 0.2 : 0.12),
                  blurRadius: 16,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Sidebar header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'KeeVault',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.search_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                          tooltip: l10n.search,
                          onPressed: onSearch,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(34, 34),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                // Group tree
                Expanded(
                  child: _GroupTreeView(
                    currentGroup: currentGroup,
                    isRecycleBin: isRecycleBin,
                    onGroupTap: onGroupTap,
                    onDeleteGroup: onDeleteGroup ?? (_) {},
                    onRenameGroup: onRenameGroup ?? (_) {},
                    onRestoreGroup: onRestoreGroup,
                    onPermanentDeleteGroup: onPermanentDeleteGroup,
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                // Toolbar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      if (onPop != null)
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            tooltip: l10n.back,
                            onPressed: onPop,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(34, 34),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(child: _BreadcrumbBar(breadcrumbs: breadcrumbs)),
                      const Spacer(),
                      _ToolbarButton(icon: Icons.add_rounded, tooltip: l10n.addEntry, onPressed: currentGroup != null ? onAddEntry : null),
                      _ToolbarButton(icon: Icons.create_new_folder_rounded, tooltip: l10n.addGroup, onPressed: currentGroup != null ? onAddGroup : null),
                      if (isOpenedFromCloud)
                        _ToolbarButton(icon: Icons.sync_rounded, tooltip: l10n.syncFromCloud, onPressed: () => _syncFromCloud(context)),
                      _ToolbarButton(icon: Icons.save_outlined, tooltip: l10n.save, onPressed: onSave, showDot: isDirty),
                      PopupMenuButton<String>(
                        tooltip: l10n.more,
                        icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                        onSelected: (v) {
                          switch (v) {
                            case 'sync_up': _syncToCloud(context);
                            case 'sync_down': _syncFromCloud(context);
                            case 'import_csv': onImportCsv?.call();
                            case 'export_csv': onExportCsv?.call();
                            case 'export_kdbx': onExportKdbx?.call();
                            case 'settings': context.push('/settings');
                            case 'about': context.push('/about');
                            case 'close': onClose();
                          }
                        },
                        itemBuilder: (_) => [
                          if (isOpenedFromCloud) ...[
                            PopupMenuItem(value: 'sync_up', child: ListTile(leading: const Icon(Icons.cloud_upload_rounded), title: Text(l10n.syncToCloud), dense: true, contentPadding: EdgeInsets.zero)),
                            PopupMenuItem(value: 'sync_down', child: ListTile(leading: const Icon(Icons.cloud_download_rounded), title: Text(l10n.syncFromCloud), dense: true, contentPadding: EdgeInsets.zero)),
                          ],
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'import_csv', child: ListTile(leading: const Icon(Icons.file_upload_rounded), title: Text(l10n.importCsv), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'export_csv', child: ListTile(leading: const Icon(Icons.file_download_rounded), title: Text(l10n.exportCsv), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'export_kdbx', child: ListTile(leading: const Icon(Icons.save_as_rounded), title: Text(l10n.exportKdbx), dense: true, contentPadding: EdgeInsets.zero)),
                          const PopupMenuDivider(),
                          PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_rounded), title: Text(l10n.settings), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'about', child: ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(l10n.about), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'close', child: ListTile(leading: const Icon(Icons.close_rounded), title: Text(l10n.closeDatabase), dense: true, contentPadding: EdgeInsets.zero)),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                // Tag filter bar
                _TagFilterBar(),
                // Entry list
                Expanded(
                  child: _EntryListBody(
                    entries: entries,
                    selectedEntry: selectedEntry,
                    onEntrySelect: onEntrySelect,
                    onEntryOpen: onEntryOpen,
                    onDeleteEntry: onDeleteEntry,
                    onRestoreEntry: onRestoreEntry,
                    onMoveEntry: onMoveEntry,
                  ),
                ),
                // Shortcut hint bar (hidden on Android where keyboard shortcuts are unavailable)
                if (selectedEntry != null && !Platform.isAndroid)
                  _ShortcutHintBar(entry: selectedEntry!),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool showDot;

  const _ToolbarButton({required this.icon, required this.tooltip, this.onPressed, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: showDot
            ? Badge(
                smallSize: 6,
                backgroundColor: colorScheme.primary,
                child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              )
            : Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(34, 34),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

// ─── Narrow layout (phone) ───────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  final List<String> breadcrumbs;
  final KdbxGroup? currentGroup;
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final bool isRecycleBin;
  final bool isOpenedFromCloud;
  final bool isDirty;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;
  final ValueChanged<KdbxGroup>? onDeleteGroup;
  final ValueChanged<KdbxGroup>? onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;
  final VoidCallback? onAddEntry;
  final VoidCallback? onAddGroup;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback? onPop;
  final VoidCallback? onImportCsv;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportKdbx;

  const _NarrowLayout({
    required this.breadcrumbs,
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.isRecycleBin,
    required this.isOpenedFromCloud,
    required this.isDirty,
    required this.onGroupTap,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.onDeleteGroup,
    this.onRenameGroup,
    this.onRestoreGroup,
    this.onPermanentDeleteGroup,
    this.onAddEntry,
    this.onAddGroup,
    required this.onSave,
    required this.onClose,
    required this.onSearch,
    this.onPop,
    this.onImportCsv,
    this.onExportCsv,
    this.onExportKdbx,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: _BreadcrumbBar(breadcrumbs: breadcrumbs),
        leading: onPop != null
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onPop)
            : null,
        actions: [
          if (isOpenedFromCloud)
            IconButton(icon: const Icon(Icons.sync_rounded, size: 20), tooltip: l10n.syncFromCloud, onPressed: () => _syncFromCloud(context)),
          IconButton(icon: const Icon(Icons.search_rounded, size: 20), tooltip: l10n.search, onPressed: onSearch),
          IconButton(
            icon: isDirty
                ? Badge(smallSize: 6, backgroundColor: colorScheme.primary, child: const Icon(Icons.save_outlined, size: 20))
                : const Icon(Icons.save_outlined, size: 20),
            tooltip: l10n.save,
            onPressed: onSave,
          ),
          PopupMenuButton<String>(
            tooltip: l10n.more,
            onSelected: (v) {
              switch (v) {
                case 'add_entry': onAddEntry?.call();
                case 'add_group': onAddGroup?.call();
                case 'sync_up': _syncToCloud(context);
                case 'sync_down': _syncFromCloud(context);
                case 'import_csv': onImportCsv?.call();
                case 'export_csv': onExportCsv?.call();
                case 'export_kdbx': onExportKdbx?.call();
                case 'settings': context.push('/settings');
                case 'about': context.push('/about');
                case 'close': onClose();
              }
            },
            itemBuilder: (_) => [
              if (onAddEntry != null)
                PopupMenuItem(value: 'add_entry', child: ListTile(leading: const Icon(Icons.add_rounded), title: Text(l10n.addEntry), dense: true, contentPadding: EdgeInsets.zero)),
              if (onAddGroup != null)
                PopupMenuItem(value: 'add_group', child: ListTile(leading: const Icon(Icons.create_new_folder_rounded), title: Text(l10n.addGroup), dense: true, contentPadding: EdgeInsets.zero)),
              if (isOpenedFromCloud) ...[
                PopupMenuItem(value: 'sync_up', child: ListTile(leading: const Icon(Icons.cloud_upload_rounded), title: Text(l10n.syncToCloud), dense: true, contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'sync_down', child: ListTile(leading: const Icon(Icons.cloud_download_rounded), title: Text(l10n.syncFromCloud), dense: true, contentPadding: EdgeInsets.zero)),
              ],
              const PopupMenuDivider(),
              PopupMenuItem(value: 'import_csv', child: ListTile(leading: const Icon(Icons.file_upload_rounded), title: Text(l10n.importCsv), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'export_csv', child: ListTile(leading: const Icon(Icons.file_download_rounded), title: Text(l10n.exportCsv), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'export_kdbx', child: ListTile(leading: const Icon(Icons.save_as_rounded), title: Text(l10n.exportKdbx), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_rounded), title: Text(l10n.settings), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'about', child: ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(l10n.about), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'close', child: ListTile(leading: const Icon(Icons.close_rounded), title: Text(l10n.closeDatabase), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _TagFilterBar(),
          Expanded(
            child: _MobileEntryListBody(
              currentGroup: currentGroup,
              entries: entries,
              selectedEntry: selectedEntry,
              onGroupTap: onGroupTap,
              onEntrySelect: onEntrySelect,
              onEntryOpen: onEntryOpen,
              onDeleteEntry: onDeleteEntry,
              onRestoreEntry: onRestoreEntry,
              onMoveEntry: onMoveEntry,
              onDeleteGroup: onDeleteGroup,
              onRenameGroup: onRenameGroup,
              onRestoreGroup: onRestoreGroup,
              onPermanentDeleteGroup: onPermanentDeleteGroup,
            ),
          ),
          if (selectedEntry != null && !Platform.isAndroid)
            _ShortcutHintBar(entry: selectedEntry!),
        ],
      ),
      floatingActionButton: currentGroup != null && onAddEntry != null
          ? FloatingActionButton(
              onPressed: onAddEntry,
              tooltip: l10n.addEntry,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

// ─── Group tree (sidebar) ────────────────────────────────────────────────

class _GroupTreeView extends ConsumerStatefulWidget {
  final KdbxGroup? currentGroup;
  final bool isRecycleBin;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxGroup> onDeleteGroup;
  final ValueChanged<KdbxGroup> onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;

  const _GroupTreeView({required this.currentGroup, required this.isRecycleBin, required this.onGroupTap, required this.onDeleteGroup, required this.onRenameGroup, this.onRestoreGroup, this.onPermanentDeleteGroup});

  @override
  ConsumerState<_GroupTreeView> createState() => _GroupTreeViewState();
}

class _GroupTreeViewState extends ConsumerState<_GroupTreeView> {
  final Set<KdbxGroup> _expanded = {};
  KdbxDatabase? _lastDb;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider).valueOrNull;
    if (db == null) return const SizedBox.shrink();

    // Expand all groups when database changes (first open or reload from cloud).
    if (!identical(db, _lastDb)) {
      _lastDb = db;
      _expanded.clear();
      _expandAll(db.root);
    }

    final visible = _flattenVisible(db.root);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final item = visible[index];
        return RepaintBoundary(child: _buildGroupTile(context, item.group, item.depth));
      },
    );
  }

  List<_GroupItem> _flattenVisible(KdbxGroup root) {
    final result = <_GroupItem>[];
    result.add(_GroupItem(root, 0));
    _flattenChildren(root, 1, result);
    return result;
  }

  void _flattenChildren(KdbxGroup group, int depth, List<_GroupItem> result) {
    if (!_expanded.contains(group)) return;
    for (final child in group.groups) {
      result.add(_GroupItem(child, depth));
      _flattenChildren(child, depth + 1, result);
    }
  }

  void _expandAll(KdbxGroup group) {
    _expanded.add(group);
    for (final child in group.groups) {
      _expandAll(child);
    }
  }

  Widget _buildGroupTile(BuildContext context, KdbxGroup group, int depth) {
    final isSelected = group == widget.currentGroup;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isTrashGroup = group.icon == KdbxIcon.trashBin;
    final canDelete = depth > 0 && !isTrashGroup;
    final hasChildren = group.groups.isNotEmpty;
    final isExpanded = _expanded.contains(group);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: isSelected
            ? BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => widget.onGroupTap(group),
            onSecondaryTapUp: canDelete ? (details) {
              if (group == widget.currentGroup) {
                _showContextMenu(context, details.globalPosition, group);
              } else {
                widget.onGroupTap(group);
              }
            } : null,
            onLongPress: canDelete ? () {
              if (group == widget.currentGroup) {
                final box = context.findRenderObject() as RenderBox?;
                final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                final size = box?.size ?? Size.zero;
                _showContextMenu(context, Offset(pos.dx + size.width / 2, pos.dy + size.height / 2), group);
              } else {
                widget.onGroupTap(group);
              }
            } : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 36,
              padding: EdgeInsets.only(left: 12.0 + depth * 18, right: 12),
              child: Row(
                children: [
                  if (hasChildren)
                    GestureDetector(
                      onTap: () => setState(() {
                        if (isExpanded) {
                          _expanded.remove(group);
                        } else {
                          _expanded.add(group);
                        }
                      }),
                      child: Icon(
                        isExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 4),
                  Icon(
                    group.icon == KdbxIcon.trashBin
                        ? (isSelected ? Icons.delete_rounded : Icons.delete_outline_rounded)
                        : depth == 0
                            ? (isSelected ? Icons.folder_open_rounded : Icons.folder_open_outlined)
                            : (isSelected ? Icons.folder_rounded : Icons.folder_outlined),
                    size: 18,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (group.entries.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.15)
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${group.entries.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPos, KdbxGroup group) {
    final l10n = AppLocalizations.of(context)!;
    final isTrashGroup = group.icon == KdbxIcon.trashBin;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screenSize = overlay.size;
    final position = RelativeRect.fromLTRB(
      globalPos.dx,
      globalPos.dy,
      screenSize.width - globalPos.dx,
      screenSize.height - globalPos.dy,
    );
    showMenu<String>(
      context: context,
      position: position,
      items: [
        if (!widget.isRecycleBin && !isTrashGroup) ...[
          PopupMenuItem(
            value: 'rename',
            child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.rename), dense: true, contentPadding: EdgeInsets.zero),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l10n.deleteGroup), dense: true, contentPadding: EdgeInsets.zero),
          ),
        ],
        if (widget.isRecycleBin && !isTrashGroup) ...[
          PopupMenuItem(
            value: 'restore',
            child: ListTile(leading: const Icon(Icons.restore_rounded), title: Text(l10n.restore), dense: true, contentPadding: EdgeInsets.zero),
          ),
          PopupMenuItem(
            value: 'permanent_delete',
            child: ListTile(leading: const Icon(Icons.delete_forever_rounded), title: Text(l10n.permanentDelete), dense: true, contentPadding: EdgeInsets.zero),
          ),
        ],
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'rename') widget.onRenameGroup(group);
      if (value == 'delete') widget.onDeleteGroup(group);
      if (value == 'restore') widget.onRestoreGroup?.call(group);
      if (value == 'permanent_delete') widget.onPermanentDeleteGroup?.call(group);
    });
  }
}

class _GroupItem {
  final KdbxGroup group;
  final int depth;
  const _GroupItem(this.group, this.depth);
}

// ─── Breadcrumb bar ──────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  final List<String> breadcrumbs;
  const _BreadcrumbBar({required this.breadcrumbs});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final displayNames = [for (final b in breadcrumbs) b == 'Root' ? l10n.rootDirectory : b];
    return Row(
      children: [
        for (int i = 0; i < displayNames.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 16, color: colorScheme.outline),
            ),
          Text(
            displayNames[i],
            style: TextStyle(
              fontSize: 14,
              fontWeight: i == displayNames.length - 1 ? FontWeight.w700 : FontWeight.w500,
              color: i == displayNames.length - 1 ? null : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Entry list ──────────────────────────────────────────────────────────

class _EntryListBody extends StatelessWidget {
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;

  const _EntryListBody({
    required this.entries,
    this.selectedEntry,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return EmptyState(icon: Icons.folder_open_rounded, message: AppLocalizations.of(context)!.thisGroupIsEmpty);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) return const SizedBox(height: 80);
        final e = entries[index];
        return RepaintBoundary(
          child: EntryListTile(
            key: ValueKey(e.uuid),
            entry: e,
            isSelected: e == selectedEntry,
            onTap: () => onEntrySelect(e),
            onOpen: () => onEntryOpen(e),
            onDelete: () => onDeleteEntry(e),
            onRestore: onRestoreEntry != null ? () => onRestoreEntry!(e) : null,
            onMove: onMoveEntry != null ? () => onMoveEntry!(e) : null,
          ),
        );
      },
    );
  }
}

// ─── Mobile entry list with group navigation ──────────────────────────────

class _MobileEntryListBody extends StatelessWidget {
  final KdbxGroup? currentGroup;
  final List<KdbxEntry> entries;
  final KdbxEntry? selectedEntry;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;
  final ValueChanged<KdbxGroup>? onDeleteGroup;
  final ValueChanged<KdbxGroup>? onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;

  const _MobileEntryListBody({
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.onGroupTap,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.onDeleteGroup,
    this.onRenameGroup,
    this.onRestoreGroup,
    this.onPermanentDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
    final subGroups = currentGroup?.groups ?? [];
    final l10n = AppLocalizations.of(context)!;

    if (subGroups.isEmpty && entries.isEmpty) {
      return EmptyState(icon: Icons.folder_open_rounded, message: l10n.thisGroupIsEmpty);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: subGroups.length + entries.length + 1,
      itemBuilder: (context, index) {
        if (index < subGroups.length) {
          return RepaintBoundary(
            child: _MobileGroupTile(
              group: subGroups[index],
              onTap: () => onGroupTap(subGroups[index]),
              onDeleteGroup: onDeleteGroup,
              onRenameGroup: onRenameGroup,
              onRestoreGroup: onRestoreGroup,
              onPermanentDeleteGroup: onPermanentDeleteGroup,
            ),
          );
        }
        final entryIndex = index - subGroups.length;
        if (entryIndex == entries.length) return const SizedBox(height: 80);
        final e = entries[entryIndex];
        return RepaintBoundary(
          child: EntryListTile(
            key: ValueKey(e.uuid),
            entry: e,
            isSelected: e == selectedEntry,
            onTap: () => onEntrySelect(e),
            onOpen: () => onEntryOpen(e),
            onDelete: () => onDeleteEntry(e),
            onRestore: onRestoreEntry != null ? () => onRestoreEntry!(e) : null,
            onMove: onMoveEntry != null ? () => onMoveEntry!(e) : null,
          ),
        );
      },
    );
  }
}

class _MobileGroupTile extends StatelessWidget {
  final KdbxGroup group;
  final VoidCallback onTap;
  final ValueChanged<KdbxGroup>? onDeleteGroup;
  final ValueChanged<KdbxGroup>? onRenameGroup;
  final ValueChanged<KdbxGroup>? onRestoreGroup;
  final ValueChanged<KdbxGroup>? onPermanentDeleteGroup;

  const _MobileGroupTile({required this.group, required this.onTap, this.onDeleteGroup, this.onRenameGroup, this.onRestoreGroup, this.onPermanentDeleteGroup});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMenu = onDeleteGroup != null || onRenameGroup != null || onRestoreGroup != null || onPermanentDeleteGroup != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isDark ? ClayColors.surfaceCardDark : ClayColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          onLongPress: hasMenu
              ? () {
                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                  final size = box?.size ?? Size.zero;
                  _showContextMenu(context, Offset(pos.dx + size.width / 2, pos.dy + size.height / 2));
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: group.icon == KdbxIcon.trashBin
                        ? colorScheme.errorContainer
                        : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    group.icon == KdbxIcon.trashBin
                        ? Icons.delete_outline_rounded
                        : Icons.folder_outlined,
                    size: 18,
                    color: group.icon == KdbxIcon.trashBin
                        ? colorScheme.onErrorContainer
                        : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (group.groups.isNotEmpty || group.entries.isNotEmpty)
                        Text(
                          _groupSubtitle(context, group),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _groupSubtitle(BuildContext context, KdbxGroup group) {
    final l10n = AppLocalizations.of(context)!;
    final parts = <String>[];
    if (group.groups.isNotEmpty) parts.add('${group.groups.length} ${l10n.groups}');
    if (group.entries.isNotEmpty) parts.add('${group.entries.length} ${l10n.entries}');
    return parts.join(' · ');
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screenSize = overlay.size;
    final position = RelativeRect.fromLTRB(
      globalPos.dx,
      globalPos.dy,
      screenSize.width - globalPos.dx,
      screenSize.height - globalPos.dy,
    );
    showMenu<String>(
      context: context,
      position: position,
      items: [
        if (onRenameGroup != null)
          PopupMenuItem(
            value: 'rename',
            child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.rename), dense: true, contentPadding: EdgeInsets.zero),
          ),
        if (onDeleteGroup != null)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l10n.deleteGroup), dense: true, contentPadding: EdgeInsets.zero),
          ),
        if (onRestoreGroup != null)
          PopupMenuItem(
            value: 'restore',
            child: ListTile(leading: const Icon(Icons.restore_rounded), title: Text(l10n.restore), dense: true, contentPadding: EdgeInsets.zero),
          ),
        if (onPermanentDeleteGroup != null)
          PopupMenuItem(
            value: 'permanent_delete',
            child: ListTile(leading: const Icon(Icons.delete_forever_rounded), title: Text(l10n.permanentDelete), dense: true, contentPadding: EdgeInsets.zero),
          ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'rename') onRenameGroup?.call(group);
      if (value == 'delete') onDeleteGroup?.call(group);
      if (value == 'restore') onRestoreGroup?.call(group);
      if (value == 'permanent_delete') onPermanentDeleteGroup?.call(group);
    });
  }
}

// ─── Add entry bottom sheet ──────────────────────────────────────────────

class _AddEntrySheet extends ConsumerStatefulWidget {
  final KdbxGroup group;
  const _AddEntrySheet({required this.group});

  @override
  ConsumerState<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<_AddEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<String> _tags = [];
  bool _obscure = true;
  KdbxEntry? _entry;
  bool _saved = false;
  bool _wasDirtyBeforeCreate = false;

  @override
  void initState() {
    super.initState();
    final service = ref.read(databaseServiceProvider);
    _wasDirtyBeforeCreate = service.isDirty;
    _entry = service.createEntry(widget.group);
  }

  @override
  void dispose() {
    if (!_saved && _entry != null) {
      widget.group.entries.remove(_entry);
      final service = ref.read(databaseServiceProvider);
      service.rebuildEntryCache();
      // Restore dirty state: if database was clean before createEntry,
      // revert to clean since we're discarding the only change.
      if (!_wasDirtyBeforeCreate) {
        service.markClean();
      }
    }
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            // Handle + header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(Icons.add_rounded, size: 16, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(l10n.newEntry, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                      const Spacer(),
                      TextButton(onPressed: _save, child: Text(l10n.save)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
            // Form
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l10n.title, prefixIcon: const Icon(Icons.title_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(labelText: l10n.username, prefixIcon: const Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          IconButton(
                            icon: const Icon(Icons.casino_outlined, size: 18),
                            tooltip: l10n.generatePassword,
                            onPressed: () async {
                              final password = await showPasswordGeneratorDialog(context);
                              if (password != null) {
                                _passwordCtrl.text = password;
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(labelText: l10n.url, prefixIcon: const Icon(Icons.link_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.notes, prefixIcon: const Icon(Icons.note_outlined)),
                  ),
                  // Tags
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (int i = 0; i < _tags.length; i++)
                          Chip(
                            label: Text(_tags[i], style: TextStyle(fontSize: 13)),
                            visualDensity: VisualDensity.compact,
                            onDeleted: () => setState(() => _tags.removeAt(i)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showAddTagDialog(l10n),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(l10n.addTag),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ),
                  if (_entry != null) ...[
                    const SizedBox(height: 8),
                    AttachmentsSection(
                      entry: _entry!,
                      service: ref.read(databaseServiceProvider),
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog(AppLocalizations l10n) {
    final ctrl = TextEditingController();
    final db = ref.read(databaseServiceProvider).db;
    final existingTags = <String>{};
    if (db != null) {
      for (final entry in db.root.allEntries) {
        final entryTags = entry.tags;
        if (entryTags != null) existingTags.addAll(entryTags);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.addTag),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.tags),
                onSubmitted: (_) {
                  final tag = ctrl.text.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() => _tags.add(tag));
                  }
                  Navigator.pop(ctx);
                },
              ),
              if (existingTags.where((t) => !_tags.contains(t)).isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in existingTags.where((t) => !_tags.contains(t)))
                      ActionChip(
                        label: Text(tag, style: TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () {
                          setState(() => _tags.add(tag));
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                final tag = ctrl.text.trim();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() => _tags.add(tag));
                }
                Navigator.pop(ctx);
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  void _save() {
    if (_entry == null) return;
    _entry!.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
    _entry!.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
    _entry!.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
    _entry!.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
    _entry!.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);
    _entry!.tags = _tags.isEmpty ? null : List.from(_tags);
    _saved = true;
    final service = ref.read(databaseServiceProvider);
    service.markDirty();
    refreshExplorerLists(ref);
    Navigator.pop(context);
  }
}

// ─── Add group bottom sheet ──────────────────────────────────────────────

class _AddGroupSheet extends ConsumerStatefulWidget {
  final KdbxGroup group;
  const _AddGroupSheet({required this.group});

  @override
  ConsumerState<_AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends ConsumerState<_AddGroupSheet> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(Icons.create_new_folder_rounded, size: 16, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.newGroup, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                    const Spacer(),
                    TextButton(onPressed: _save, child: Text(l10n.save)),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(minimumSize: const Size(32, 32)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.groupName,
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_nameCtrl.text.isEmpty) return;
    final service = ref.read(databaseServiceProvider);
    service.createGroup(widget.group, _nameCtrl.text);
    refreshExplorerLists(ref);
    if (mounted) Navigator.pop(context);
  }
}

// ─── Tag filter bar ────────────────────────────────────────────────────

class _TagFilterBar extends ConsumerWidget {
  const _TagFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTags = ref.watch(allTagsProvider);
    if (allTags.isEmpty) return const SizedBox.shrink();

    final selectedTag = ref.watch(selectedTagProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Icon(Icons.label_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 4),
          _TagChip(
            label: l10n.allTags,
            selected: selectedTag == null,
            onTap: () => ref.read(selectedTagProvider.notifier).state = null,
          ),
          for (final tag in allTags)
            _TagChip(
              label: tag,
              selected: selectedTag == tag,
              onTap: () => ref.read(selectedTagProvider.notifier).state = selectedTag == tag ? null : tag,
            ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Material(
        color: selected ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shortcut hint bar ─────────────────────────────────────────────────

class _ShortcutHintBar extends StatelessWidget {
  final KdbxEntry entry;
  const _ShortcutHintBar({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final username = entry.fields['UserName']?.text ?? '';
    final password = entry.fields['Password']?.text ?? '';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Icon(Icons.keyboard_rounded, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) ...[
              const _KeyChip(label: 'Ctrl+F'),
              const SizedBox(width: 4),
              Text(l10n.shortcutSearch, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 16),
              const _KeyChip(label: 'Ctrl+S'),
              const SizedBox(width: 4),
              Text(l10n.shortcutSave, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 16),
            ],
            if (username.isNotEmpty) ...[
              const _KeyChip(label: 'Ctrl+B'),
              const SizedBox(width: 4),
              Text(l10n.copyUsername, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 16),
            ],
            if (password.isNotEmpty) ...[
              const _KeyChip(label: 'Ctrl+C'),
              const SizedBox(width: 4),
              Text(l10n.copyPassword, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 16),
            ],
            const _KeyChip(label: 'Ctrl+U'),
            const SizedBox(width: 4),
            Text(l10n.copyUrl, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(width: 16),
            const _KeyChip(label: 'Ctrl+T'),
            const SizedBox(width: 4),
            Text(l10n.copyTotp, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  final String label;
  const _KeyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

// ─── Sync helpers ───────────────────────────────────────────────────────

Future<void> _syncToCloud(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context)!;
  final config = await container.read(webDavSettingsServiceProvider).getConfig();
  if (config == null || !config.enabled) {
    if (context.mounted) {
      showToast(context, l10n.pleaseConfigureWebDAV, isError: true);
      context.push('/settings');
    }
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 16),
            Text(l10n.uploadingToCloud, style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface)),
          ],
        ),
      ),
    ),
  );
  try {
    await container.read(databaseProvider.notifier).forceUpload();
    if (context.mounted) {
      Navigator.of(context).pop();
      final syncState = container.read(syncStateProvider);
      if (syncState == SyncState.success) {
        showToast(context, l10n.syncedToCloud);
      } else {
        final error = container.read(databaseProvider.notifier).lastSyncError;
        if (context.mounted) {
          _showSyncErrorDialog(context, _translateSyncError(error ?? Exception('unknown'), l10n));
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSyncErrorDialog(context, _translateSyncError(e, l10n));
    }
  }
}

Future<void> _syncFromCloud(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final l10n = AppLocalizations.of(context)!;
  final config = await container.read(webDavSettingsServiceProvider).getConfig();
  if (config == null || !config.enabled) {
    if (context.mounted) {
      _showSyncErrorDialog(context, l10n.pleaseConfigureWebDAV);
    }
    return;
  }
  if (!context.mounted) return;
  final syncService = container.read(syncServiceProvider);
  final exists = await syncService.remoteFileExists(config);
  if (!exists) {
    if (context.mounted) {
      _showSyncErrorDialog(context, l10n.cloudNoDatabaseSaveFirst);
    }
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(height: 16),
            Text(l10n.downloadingFromCloudShort, style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface)),
          ],
        ),
      ),
    ),
  );
  try {
    final container = ProviderScope.containerOf(context);
    await container.read(databaseProvider.notifier).reloadFromCloud();
    container.invalidate(entriesProvider);
    if (context.mounted) {
      Navigator.of(context).pop();
      showToast(context, l10n.syncedFromCloud);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSyncErrorDialog(context, _translateSyncError(e, l10n));
    }
  }
}

String _translateSyncError(Object e, AppLocalizations l10n) {
  if (e is SyncException) {
    switch (e.type) {
      case SyncErrorType.network:
        return l10n.syncErrorNetwork;
      case SyncErrorType.auth:
        return l10n.syncErrorAuth;
      case SyncErrorType.notFound:
        return l10n.syncErrorNotFound;
      case SyncErrorType.timeout:
        return l10n.syncErrorTimeout;
      case SyncErrorType.serverError:
        return l10n.syncErrorServer;
      case SyncErrorType.unknown:
        break;
    }
  }
  final msg = e.toString().replaceFirst('Exception: ', '');
  if (msg == 'please_configure_webdav') return l10n.pleaseConfigureWebDAVFirst;
  if (msg == 'cloud_database_not_exist') return l10n.cloudDatabaseNotExist;
  if (msg == 'remote_database_not_exist') return l10n.remoteDatabaseNotExist;
  return l10n.syncFailedWithError(msg);
}

void _showSyncErrorDialog(BuildContext context, String message) {
  final l10n = AppLocalizations.of(context)!;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(l10n.cancel),
          ),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.push('/settings');
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(l10n.goToSettings),
        ),
      ],
    ),
  );
}
