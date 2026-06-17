import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/move_to_group_dialog.dart';
import '../../../core/widgets/attachments_section.dart';
import '../../../core/widgets/change_password_dialog.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../providers/explorer_provider.dart';

class ExplorerScreen extends ConsumerWidget {
  const ExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(databaseProvider);

    return dbAsync.when(
      data: (db) {
        if (db == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/welcome'));
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
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final selected = ref.read(selectedEntryProvider);
    if (selected == null) return;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    if (!isCtrl) return;

    if (event.logicalKey == LogicalKeyboardKey.keyB) {
      final username = selected.fields['UserName']?.text ?? '';
      if (username.isNotEmpty) {
        copyToClipboardWithAutoClear(username);
        if (mounted) showToast(context, AppLocalizations.of(context)!.copiedUsername);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final password = selected.fields['Password']?.text ?? '';
      if (password.isNotEmpty) {
        copyToClipboardWithAutoClear(password);
        if (mounted) showToast(context, AppLocalizations.of(context)!.copiedPassword);
      }
    }
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
    final isRecycleBin = currentGroup?.icon == KdbxIcon.trashBin;
    final isOpenedFromCloud = ref.watch(openedFromCloudProvider);
    final selectedEntry = ref.watch(selectedEntryProvider);

    void onEntrySelect(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
    }

    void onEntryOpen(KdbxEntry entry) {
      ref.read(selectedEntryProvider.notifier).state = entry;
      final idx = currentGroup?.entries.indexOf(entry) ?? 0;
      final path = service.getGroupPath(currentGroup!);
      context.push('/entry/detail?index=$idx&groupPath=${Uri.encodeComponent(path)}');
    }

    if (isWide) {
      return Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _handleKeyEvent(event);
          return KeyEventResult.ignored;
        },
        child: _WideLayout(
          breadcrumbs: breadcrumbs,
          currentGroup: currentGroup,
          entries: entries,
          selectedEntry: selectedEntry,
          isRecycleBin: isRecycleBin,
          isOpenedFromCloud: isOpenedFromCloud,
          onGroupTap: (group) {
            ref.read(selectedEntryProvider.notifier).state = null;
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
          onAddEntry: isRecycleBin ? null : () => _showAddEntrySheet(context, ref, currentGroup!),
          onAddGroup: isRecycleBin ? null : () => _showAddGroupSheet(context, ref, currentGroup!),
          onSave: () => _save(context, ref),
          onClose: () => _close(context, ref),
          onSearch: () => context.push('/search'),
          onPop: _popPath(ref),
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.ignored;
      },
      child: _NarrowLayout(
        breadcrumbs: breadcrumbs,
        currentGroup: currentGroup,
        entries: entries,
        selectedEntry: selectedEntry,
        isRecycleBin: isRecycleBin,
        isOpenedFromCloud: isOpenedFromCloud,
        onGroupTap: (group) {
          ref.read(selectedEntryProvider.notifier).state = null;
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
        onAddEntry: isRecycleBin ? null : () => _showAddEntrySheet(context, ref, currentGroup!),
        onAddGroup: isRecycleBin ? null : () => _showAddGroupSheet(context, ref, currentGroup!),
        onSave: () => _save(context, ref),
        onClose: () => _close(context, ref),
        onSearch: () => context.push('/search'),
        onPop: _popPath(ref),
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

  void _showAddEntrySheet(BuildContext context, WidgetRef ref, KdbxGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddEntrySheet(group: group, ref: ref),
    );
  }

  void _showAddGroupSheet(BuildContext context, WidgetRef ref, KdbxGroup group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddGroupSheet(group: group, ref: ref),
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
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;
  final ValueChanged<KdbxGroup>? onDeleteGroup;
  final ValueChanged<KdbxGroup>? onRenameGroup;
  final VoidCallback? onAddEntry;
  final VoidCallback? onAddGroup;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback? onPop;

  const _WideLayout({
    required this.breadcrumbs,
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.isRecycleBin,
    required this.isOpenedFromCloud,
    required this.onGroupTap,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.onDeleteGroup,
    this.onRenameGroup,
    this.onAddEntry,
    this.onAddGroup,
    required this.onSave,
    required this.onClose,
    required this.onSearch,
    this.onPop,
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
                  color: (isDark ? Colors.black : const Color(0xFF8AB8B3)).withValues(alpha: isDark ? 0.2 : 0.12),
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
                    onGroupTap: onGroupTap,
                    onDeleteGroup: onDeleteGroup ?? (_) {},
                    onRenameGroup: onRenameGroup ?? (_) {},
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
                      _ToolbarButton(icon: Icons.save_outlined, tooltip: l10n.save, onPressed: onSave),
                      PopupMenuButton<String>(
                        tooltip: l10n.more,
                        icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                        onSelected: (v) {
                          switch (v) {
                            case 'sync_up': _syncToCloud(context);
                            case 'sync_down': _syncFromCloud(context);
                            case 'change_password': showChangePasswordDialog(context);
                            case 'settings': context.push('/settings');
                            case 'about': context.push('/about');
                            case 'close': onClose();
                          }
                        },
                        itemBuilder: (_) => [
                          if (isOpenedFromCloud) ...[
                            PopupMenuItem(value: 'sync_up', child: ListTile(leading: const Icon(Icons.cloud_upload_rounded), title: Text(l10n.syncToCloud), dense: true, contentPadding: EdgeInsets.zero)),
                            PopupMenuItem(value: 'sync_down', child: ListTile(leading: const Icon(Icons.cloud_download_rounded), title: Text(l10n.downloadFromCloud), dense: true, contentPadding: EdgeInsets.zero)),
                          ],
                          PopupMenuItem(value: 'change_password', child: ListTile(leading: const Icon(Icons.key_rounded), title: Text(l10n.changeMasterPassword), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_rounded), title: Text(l10n.settings), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'about', child: ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(l10n.about), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'close', child: ListTile(leading: const Icon(Icons.close_rounded), title: Text(l10n.closeDatabase), dense: true, contentPadding: EdgeInsets.zero)),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
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
                // Shortcut hint bar
                if (selectedEntry != null)
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

  const _ToolbarButton({required this.icon, required this.tooltip, this.onPressed});

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
        icon: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
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
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntrySelect;
  final ValueChanged<KdbxEntry> onEntryOpen;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;
  final VoidCallback? onAddEntry;
  final VoidCallback? onAddGroup;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final VoidCallback onSearch;
  final VoidCallback? onPop;

  const _NarrowLayout({
    required this.breadcrumbs,
    required this.currentGroup,
    required this.entries,
    this.selectedEntry,
    required this.isRecycleBin,
    required this.isOpenedFromCloud,
    required this.onGroupTap,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.onAddEntry,
    this.onAddGroup,
    required this.onSave,
    required this.onClose,
    required this.onSearch,
    this.onPop,
  });

  @override
  Widget build(BuildContext context) {
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
          PopupMenuButton<String>(
            tooltip: l10n.more,
            onSelected: (v) {
              switch (v) {
                case 'add_entry': onAddEntry?.call();
                case 'add_group': onAddGroup?.call();
                case 'save': onSave();
                case 'sync_up': _syncToCloud(context);
                case 'sync_down': _syncFromCloud(context);
                case 'change_password': showChangePasswordDialog(context);
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
              PopupMenuItem(value: 'save', child: ListTile(leading: const Icon(Icons.save_outlined), title: Text(l10n.save), dense: true, contentPadding: EdgeInsets.zero)),
              if (isOpenedFromCloud) ...[
                PopupMenuItem(value: 'sync_up', child: ListTile(leading: const Icon(Icons.cloud_upload_rounded), title: Text(l10n.syncToCloud), dense: true, contentPadding: EdgeInsets.zero)),
                PopupMenuItem(value: 'sync_down', child: ListTile(leading: const Icon(Icons.cloud_download_rounded), title: Text(l10n.downloadFromCloud), dense: true, contentPadding: EdgeInsets.zero)),
              ],
              PopupMenuItem(value: 'change_password', child: ListTile(leading: const Icon(Icons.key_rounded), title: Text(l10n.changeMasterPassword), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_rounded), title: Text(l10n.settings), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'about', child: ListTile(leading: const Icon(Icons.info_outline_rounded), title: Text(l10n.about), dense: true, contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'close', child: ListTile(leading: const Icon(Icons.close_rounded), title: Text(l10n.closeDatabase), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
            ),
          ),
          if (selectedEntry != null)
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
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxGroup> onDeleteGroup;
  final ValueChanged<KdbxGroup> onRenameGroup;

  const _GroupTreeView({required this.currentGroup, required this.onGroupTap, required this.onDeleteGroup, required this.onRenameGroup});

  @override
  ConsumerState<_GroupTreeView> createState() => _GroupTreeViewState();
}

class _GroupTreeViewState extends ConsumerState<_GroupTreeView> {
  final Set<KdbxGroup> _expanded = {};
  bool _didInitExpand = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider).valueOrNull;
    if (db == null) return const SizedBox.shrink();

    // Expand all groups by default on first build after database opens.
    if (!_didInitExpand) {
      _didInitExpand = true;
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
    final canDelete = depth > 0 && group.icon != KdbxIcon.trashBin;
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
            onSecondaryTapUp: canDelete ? (details) => _showContextMenu(context, details.globalPosition, group) : null,
            onLongPress: canDelete ? () {
              final box = context.findRenderObject() as RenderBox?;
              final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
              final size = box?.size ?? Size.zero;
              _showContextMenu(context, Offset(pos.dx + size.width / 2, pos.dy + size.height / 2), group);
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
        PopupMenuItem(
          value: 'rename',
          child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.rename), dense: true, contentPadding: EdgeInsets.zero),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(l10n.deleteGroup), dense: true, contentPadding: EdgeInsets.zero),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'rename') widget.onRenameGroup(group);
      if (value == 'delete') widget.onDeleteGroup(group);
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

  const _MobileGroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isDark ? ClayColors.surfaceCardDark : ClayColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
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
}

// ─── Add entry bottom sheet ──────────────────────────────────────────────

class _AddEntrySheet extends StatefulWidget {
  final KdbxGroup group;
  final WidgetRef ref;
  const _AddEntrySheet({required this.group, required this.ref});

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _obscure = true;
  KdbxEntry? _entry;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final service = widget.ref.read(databaseServiceProvider);
    _entry = service.createEntry(widget.group);
  }

  @override
  void dispose() {
    if (!_saved && _entry != null) {
      widget.group.entries.remove(_entry);
      final service = widget.ref.read(databaseServiceProvider);
      service.rebuildEntryCache();
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
                  if (_entry != null) ...[
                    const SizedBox(height: 8),
                    AttachmentsSection(
                      entry: _entry!,
                      service: widget.ref.read(databaseServiceProvider),
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

  void _save() {
    if (_entry == null) return;
    _entry!.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
    _entry!.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
    _entry!.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
    _entry!.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
    _entry!.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);
    _saved = true;
    final service = widget.ref.read(databaseServiceProvider);
    service.markDirty();
    refreshExplorerLists(widget.ref);
    Navigator.pop(context);
  }
}

// ─── Add group bottom sheet ──────────────────────────────────────────────

class _AddGroupSheet extends StatefulWidget {
  final KdbxGroup group;
  final WidgetRef ref;
  const _AddGroupSheet({required this.group, required this.ref});

  @override
  State<_AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends State<_AddGroupSheet> {
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
    final service = widget.ref.read(databaseServiceProvider);
    service.createGroup(widget.group, _nameCtrl.text);
    refreshExplorerLists(widget.ref);
    if (mounted) Navigator.pop(context);
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
      child: Row(
        children: [
          Icon(Icons.keyboard_rounded, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
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
          ],
        ],
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
        showToast(context, l10n.syncFailed, isError: true);
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      showToast(context, l10n.syncFailedWithError(e.toString()), isError: true);
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
    final group = container.read(currentGroupProvider);
    container.read(entriesProvider.notifier).state = [...?group?.entries];
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
