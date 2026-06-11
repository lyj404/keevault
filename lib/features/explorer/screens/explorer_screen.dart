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
import '../../../core/widgets/toast.dart';
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
      loading: () => Scaffold(body: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
      error: (e, _) => Scaffold(body: Center(child: Text('错误: $e'))),
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
        if (mounted) showToast(context, '已复制用户名');
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
      final password = selected.fields['Password']?.text ?? '';
      if (password.isNotEmpty) {
        copyToClipboardWithAutoClear(password);
        if (mounted) showToast(context, '已复制密码');
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('云端有新版本'),
        content: const Text('检测到云端数据库已被其他设备修改，是否同步最新版本？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('忽略'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncFromCloud(context);
            },
            child: const Text('同步'),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除条目'),
        content: const Text('确定将此条目移至回收站？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              ref.read(databaseServiceProvider).deleteItem(entry);
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, '已移至回收站');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _permanentDeleteEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('永久删除'),
        content: const Text('此操作不可撤销，确定删除？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
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
              if (context.mounted) showToast(context, '已永久删除');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _restoreEntry(BuildContext context, WidgetRef ref, KdbxEntry entry) {
    final service = ref.read(databaseServiceProvider);
    final success = service.restoreItem(entry);
    if (success) {
      refreshExplorerLists(ref);
      showToast(context, '已恢复');
    } else {
      showToast(context, '恢复失败：找不到原始分组', isError: true);
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
      showToast(context, '已移动');
    }
  }

  void _deleteGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    if (group.entries.isNotEmpty || group.groups.isNotEmpty) {
      showToast(context, '不能删除非空分组', isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定删除分组"${group.name}"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              ref.read(databaseServiceProvider).deleteItem(group);
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
              if (context.mounted) showToast(context, '已移至回收站');
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _renameGroup(BuildContext context, WidgetRef ref, KdbxGroup group) {
    final ctrl = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分组名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final newName = ctrl.text.trim();
              if (newName.isEmpty) return;
              group.name = newName;
              ref.read(databaseServiceProvider).markDirty();
              refreshExplorerLists(ref);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
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
    ref.read(databaseProvider.notifier).save().then((success) {
      if (!context.mounted) return;
      if (success) {
        showToast(context, '已保存');
      } else {
        _showConflictDialog(context, ref);
      }
    });
  }

  void _showConflictDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('同步冲突'),
        content: const Text('云端数据库已被其他设备修改。你可以选择覆盖云端版本（以本地为准），或先下载云端版本再编辑。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _syncFromCloud(context);
            },
            child: const Text('下载云端版本'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _forceUpload(context, ref);
            },
            child: const Text('覆盖云端'),
          ),
        ],
      ),
    );
  }

  void _forceUpload(BuildContext context, WidgetRef ref) {
    ref.read(databaseProvider.notifier).forceUpload().then((_) {
      if (context.mounted) {
        final syncState = ref.read(syncStateProvider);
        if (syncState == SyncState.success) {
          showToast(context, '已覆盖同步到云端');
        } else if (syncState == SyncState.error) {
          showToast(context, '同步失败', isError: true);
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
                          tooltip: '搜索',
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
                            tooltip: '返回',
                            onPressed: onPop,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(34, 34),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Expanded(child: _BreadcrumbBar(breadcrumbs: breadcrumbs)),
                      const Spacer(),
                      _ToolbarButton(icon: Icons.add_rounded, tooltip: '添加条目', onPressed: currentGroup != null ? onAddEntry : null),
                      _ToolbarButton(icon: Icons.create_new_folder_rounded, tooltip: '添加分组', onPressed: currentGroup != null ? onAddGroup : null),
                      if (isOpenedFromCloud)
                        _ToolbarButton(icon: Icons.sync_rounded, tooltip: '从云端同步', onPressed: () => _syncFromCloud(context)),
                      _ToolbarButton(icon: Icons.save_outlined, tooltip: '保存', onPressed: onSave),
                      PopupMenuButton<String>(
                        tooltip: '更多',
                        icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                        onSelected: (v) {
                          switch (v) {
                            case 'sync_up': _syncToCloud(context);
                            case 'sync_down': _syncFromCloud(context);
                            case 'settings': context.push('/settings');
                            case 'close': onClose();
                          }
                        },
                        itemBuilder: (_) => [
                          if (isOpenedFromCloud) ...[
                            const PopupMenuItem(value: 'sync_up', child: ListTile(leading: Icon(Icons.cloud_upload_rounded), title: Text('同步到云端'), dense: true, contentPadding: EdgeInsets.zero)),
                            const PopupMenuItem(value: 'sync_down', child: ListTile(leading: Icon(Icons.cloud_download_rounded), title: Text('从云端下载'), dense: true, contentPadding: EdgeInsets.zero)),
                            const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_rounded), title: Text('同步设置'), dense: true, contentPadding: EdgeInsets.zero)),
                          ],
                          const PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.close_rounded), title: Text('关闭数据库'), dense: true, contentPadding: EdgeInsets.zero)),
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
    return Scaffold(
      appBar: AppBar(
        title: _BreadcrumbBar(breadcrumbs: breadcrumbs),
        leading: onPop != null
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onPop)
            : null,
        actions: [
          if (isOpenedFromCloud)
            IconButton(icon: const Icon(Icons.sync_rounded, size: 20), tooltip: '从云端同步', onPressed: () => _syncFromCloud(context)),
          IconButton(icon: const Icon(Icons.search_rounded, size: 20), tooltip: '搜索', onPressed: onSearch),
          PopupMenuButton<String>(
            tooltip: '更多',
            onSelected: (v) {
              switch (v) {
                case 'add_entry': onAddEntry?.call();
                case 'add_group': onAddGroup?.call();
                case 'save': onSave();
                case 'sync_up': _syncToCloud(context);
                case 'sync_down': _syncFromCloud(context);
                case 'settings': context.push('/settings');
                case 'close': onClose();
              }
            },
            itemBuilder: (_) => [
              if (onAddEntry != null)
                const PopupMenuItem(value: 'add_entry', child: ListTile(leading: Icon(Icons.add_rounded), title: Text('添加条目'), dense: true, contentPadding: EdgeInsets.zero)),
              if (onAddGroup != null)
                const PopupMenuItem(value: 'add_group', child: ListTile(leading: Icon(Icons.create_new_folder_rounded), title: Text('添加分组'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_outlined), title: Text('保存'), dense: true, contentPadding: EdgeInsets.zero)),
              if (isOpenedFromCloud) ...[
                const PopupMenuItem(value: 'sync_up', child: ListTile(leading: Icon(Icons.cloud_upload_rounded), title: Text('同步到云端'), dense: true, contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'sync_down', child: ListTile(leading: Icon(Icons.cloud_download_rounded), title: Text('从云端下载'), dense: true, contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_rounded), title: Text('同步设置'), dense: true, contentPadding: EdgeInsets.zero)),
              ],
              const PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.close_rounded), title: Text('关闭数据库'), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
          if (selectedEntry != null)
            _ShortcutHintBar(entry: selectedEntry!),
        ],
      ),
      floatingActionButton: currentGroup != null && onAddEntry != null
          ? FloatingActionButton(
              onPressed: onAddEntry,
              tooltip: '添加条目',
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

// ─── Group tree (sidebar) ────────────────────────────────────────────────

class _GroupTreeView extends ConsumerWidget {
  final KdbxGroup? currentGroup;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxGroup> onDeleteGroup;
  final ValueChanged<KdbxGroup> onRenameGroup;

  const _GroupTreeView({required this.currentGroup, required this.onGroupTap, required this.onDeleteGroup, required this.onRenameGroup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider).valueOrNull;
    if (db == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      children: [
        _buildGroupTile(context, db.root, 0),
        ..._buildChildren(context, db.root, 1),
      ],
    );
  }

  Widget _buildGroupTile(BuildContext context, KdbxGroup group, int depth) {
    final isSelected = group == currentGroup;
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final canDelete = depth > 0 && group.icon != KdbxIcon.trashBin;

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
            onTap: () => onGroupTap(group),
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
                        color: isSelected ? colorScheme.onPrimaryContainer : null,
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
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('重命名'), dense: true, contentPadding: EdgeInsets.zero),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('删除分组'), dense: true, contentPadding: EdgeInsets.zero),
        ),
      ],
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'rename') onRenameGroup(group);
      if (value == 'delete') onDeleteGroup(group);
    });
  }

  List<Widget> _buildChildren(BuildContext context, KdbxGroup group, int depth) {
    final widgets = <Widget>[];
    for (final child in group.groups) {
      widgets.add(_buildGroupTile(context, child, depth));
      widgets.addAll(_buildChildren(context, child, depth + 1));
    }
    return widgets;
  }
}

// ─── Breadcrumb bar ──────────────────────────────────────────────────────

class _BreadcrumbBar extends StatelessWidget {
  final List<String> breadcrumbs;
  const _BreadcrumbBar({required this.breadcrumbs});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayNames = [for (final b in breadcrumbs) b == 'Root' ? '根目录' : b];
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
      return const EmptyState(icon: Icons.folder_open_rounded, message: '此分组为空');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == entries.length) return const SizedBox(height: 80);
        final e = entries[index];
        return EntryListTile(
          entry: e,
          isSelected: e == selectedEntry,
          onTap: () => onEntrySelect(e),
          onOpen: () => onEntryOpen(e),
          onDelete: () => onDeleteEntry(e),
          onRestore: onRestoreEntry != null ? () => onRestoreEntry!(e) : null,
          onMove: onMoveEntry != null ? () => onMoveEntry!(e) : null,
        );
      },
    );
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

  @override
  void dispose() {
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
                      const Text('新建条目', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(onPressed: _save, child: const Text('保存')),
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
                    decoration: const InputDecoration(labelText: '标题', prefixIcon: Icon(Icons.title_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: '用户名', prefixIcon: Icon(Icons.person_outline_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '密码',
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
                            tooltip: '生成密码',
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
                    decoration: const InputDecoration(labelText: '网址', prefixIcon: Icon(Icons.link_rounded)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '备注', prefixIcon: Icon(Icons.note_outlined)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final service = widget.ref.read(databaseServiceProvider);
    final entry = service.createEntry(widget.group);
    entry.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
    entry.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
    entry.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
    entry.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
    entry.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);
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
                    const Text('新建分组', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton(onPressed: _save, child: const Text('保存')),
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
              decoration: const InputDecoration(
                labelText: '分组名称',
                prefixIcon: Icon(Icons.folder_outlined),
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
            _KeyChip(label: 'Ctrl+B'),
            const SizedBox(width: 4),
            Text('复制用户名', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            const SizedBox(width: 16),
          ],
          if (password.isNotEmpty) ...[
            _KeyChip(label: 'Ctrl+C'),
            const SizedBox(width: 4),
            Text('复制密码', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
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
  final config = await container.read(webDavSettingsServiceProvider).getConfig();
  if (config == null || !config.enabled) {
    if (context.mounted) {
      showToast(context, '请先在设置中配置 WebDAV', isError: true);
      context.push('/settings');
    }
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(height: 16),
            Text('正在同步到云端...', style: TextStyle(fontSize: 14)),
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
        showToast(context, '已同步到云端');
      } else {
        showToast(context, '同步失败', isError: true);
      }
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      showToast(context, '同步失败: $e', isError: true);
    }
  }
}

Future<void> _syncFromCloud(BuildContext context) async {
  final container = ProviderScope.containerOf(context);
  final config = await container.read(webDavSettingsServiceProvider).getConfig();
  if (config == null || !config.enabled) {
    if (context.mounted) {
      _showSyncErrorDialog(context, '请先在设置中配置 WebDAV');
    }
    return;
  }
  if (!context.mounted) return;
  final syncService = container.read(syncServiceProvider);
  final exists = await syncService.remoteFileExists(config);
  if (!exists) {
    if (context.mounted) {
      _showSyncErrorDialog(context, '云端还没有数据库，请先保存本地数据库后同步');
    }
    return;
  }
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Dialog(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(height: 16),
            Text('正在从云端下载...', style: TextStyle(fontSize: 14)),
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
      showToast(context, '已从云端同步');
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      _showSyncErrorDialog(context, '同步失败: $e');
    }
  }
}

void _showSyncErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('取消'),
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
          child: const Text('去设置'),
        ),
      ],
    ),
  );
}
