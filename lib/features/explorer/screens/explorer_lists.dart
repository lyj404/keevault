part of 'explorer_screen.dart';

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
  final bool isMultiSelect;
  final Set<KdbxEntry> selectedEntries;
  final ValueChanged<KdbxEntry> onToggleEntrySelection;
  final bool isDraggable;

  const _EntryListBody({
    required this.entries,
    this.selectedEntry,
    required this.onEntrySelect,
    required this.onEntryOpen,
    required this.onDeleteEntry,
    this.onRestoreEntry,
    this.onMoveEntry,
    this.isMultiSelect = false,
    this.selectedEntries = const {},
    required this.onToggleEntrySelection,
    this.isDraggable = false,
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
            onTap: isMultiSelect ? () => onToggleEntrySelection(e) : () => onEntrySelect(e),
            onOpen: () => onEntryOpen(e),
            onDelete: () => onDeleteEntry(e),
            onRestore: onRestoreEntry != null ? () => onRestoreEntry!(e) : null,
            onMove: onMoveEntry != null ? () => onMoveEntry!(e) : null,
            showCheckbox: isMultiSelect,
            isChecked: selectedEntries.contains(e),
            draggable: isDraggable,
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
  final bool isMultiSelect;
  final Set<KdbxEntry> selectedEntries;
  final ValueChanged<KdbxEntry> onToggleEntrySelection;

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
    this.isMultiSelect = false,
    this.selectedEntries = const {},
    required this.onToggleEntrySelection,
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
            onTap: isMultiSelect ? () => onToggleEntrySelection(e) : () => onEntrySelect(e),
            onOpen: () => onEntryOpen(e),
            onDelete: () => onDeleteEntry(e),
            onRestore: onRestoreEntry != null ? () => onRestoreEntry!(e) : null,
            onMove: onMoveEntry != null ? () => onMoveEntry!(e) : null,
            showCheckbox: isMultiSelect,
            isChecked: selectedEntries.contains(e),
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
