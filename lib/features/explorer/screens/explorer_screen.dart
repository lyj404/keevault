import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../core/widgets/entry_list_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/move_to_group_dialog.dart';
import '../../../core/widgets/toast.dart';
import '../../database/providers/database_provider.dart';
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

class _ExplorerBodyState extends ConsumerState<_ExplorerBody> {
  @override
  Widget build(BuildContext context) {
    final currentGroup = ref.watch(currentGroupProvider);
    final entries = ref.watch(entriesProvider);
    final breadcrumbs = ref.watch(breadcrumbProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final service = ref.read(databaseServiceProvider);
    final isRecycleBin = currentGroup?.icon == KdbxIcon.trashBin;

    if (isWide) {
      return _WideLayout(
        breadcrumbs: breadcrumbs,
        currentGroup: currentGroup,
        entries: entries,
        isRecycleBin: isRecycleBin,
        onGroupTap: (group) {
          final path = service.getGroupPath(group);
          ref.read(currentGroupPathProvider.notifier).state = path;
        },
        onEntryTap: (entry) {
          final idx = currentGroup?.entries.indexOf(entry) ?? 0;
          final path = service.getGroupPath(currentGroup!);
          context.push('/entry/detail?index=$idx&groupPath=${Uri.encodeComponent(path)}');
        },
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
      );
    }

    return _NarrowLayout(
      breadcrumbs: breadcrumbs,
      currentGroup: currentGroup,
      entries: entries,
      isRecycleBin: isRecycleBin,
      onEntryTap: (entry) {
        final idx = currentGroup?.entries.indexOf(entry) ?? 0;
        final path = service.getGroupPath(currentGroup!);
        context.push('/entry/detail?index=$idx&groupPath=${Uri.encodeComponent(path)}');
      },
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
    ref.read(databaseProvider.notifier).save().then((_) {
      if (context.mounted) {
        showToast(context, '已保存');
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
  final bool isRecycleBin;
  final ValueChanged<KdbxGroup> onGroupTap;
  final ValueChanged<KdbxEntry> onEntryTap;
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
    required this.isRecycleBin,
    required this.onGroupTap,
    required this.onEntryTap,
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
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [ClayColors.primary, ClayColors.tertiary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: ClayColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
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
                      _ToolbarButton(icon: Icons.save_outlined, tooltip: '保存', onPressed: onSave),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                        onSelected: (v) {
                          if (v == 'close') onClose();
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'close', child: Text('关闭数据库')),
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
                    onEntryTap: onEntryTap,
                    onDeleteEntry: onDeleteEntry,
                    onRestoreEntry: onRestoreEntry,
                    onMoveEntry: onMoveEntry,
                  ),
                ),
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
  final bool isRecycleBin;
  final ValueChanged<KdbxEntry> onEntryTap;
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
    required this.isRecycleBin,
    required this.onEntryTap,
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
          IconButton(icon: const Icon(Icons.search_rounded, size: 20), tooltip: '搜索', onPressed: onSearch),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'add_entry': onAddEntry?.call();
                case 'add_group': onAddGroup?.call();
                case 'save': onSave();
                case 'close': onClose();
              }
            },
            itemBuilder: (_) => [
              if (onAddEntry != null)
                const PopupMenuItem(value: 'add_entry', child: ListTile(leading: Icon(Icons.add_rounded), title: Text('添加条目'), dense: true, contentPadding: EdgeInsets.zero)),
              if (onAddGroup != null)
                const PopupMenuItem(value: 'add_group', child: ListTile(leading: Icon(Icons.create_new_folder_rounded), title: Text('添加分组'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_outlined), title: Text('保存'), dense: true, contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'close', child: ListTile(leading: Icon(Icons.close_rounded), title: Text('关闭数据库'), dense: true, contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: _EntryListBody(
        entries: entries,
        onEntryTap: onEntryTap,
        onDeleteEntry: onDeleteEntry,
        onRestoreEntry: onRestoreEntry,
        onMoveEntry: onMoveEntry,
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
  final ValueChanged<KdbxEntry> onEntryTap;
  final ValueChanged<KdbxEntry> onDeleteEntry;
  final ValueChanged<KdbxEntry>? onRestoreEntry;
  final ValueChanged<KdbxEntry>? onMoveEntry;

  const _EntryListBody({
    required this.entries,
    required this.onEntryTap,
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
          onTap: () => onEntryTap(e),
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
