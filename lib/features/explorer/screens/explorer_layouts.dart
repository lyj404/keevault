part of 'explorer_screen.dart';

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
  final EntrySortOption sortOption;
  final ValueChanged<EntrySortOption> onSortChanged;
  final bool isMultiSelect;
  final Set<KdbxEntry> selectedEntries;
  final VoidCallback onToggleMultiSelect;
  final ValueChanged<KdbxEntry> onToggleEntrySelection;
  final VoidCallback onSelectAll;
  final VoidCallback onCancelSelection;
  final VoidCallback onBatchDelete;
  final VoidCallback onBatchMove;
  final VoidCallback onBatchTag;

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
    required this.sortOption,
    required this.onSortChanged,
    required this.isMultiSelect,
    required this.selectedEntries,
    required this.onToggleMultiSelect,
    required this.onToggleEntrySelection,
    required this.onSelectAll,
    required this.onCancelSelection,
    required this.onBatchDelete,
    required this.onBatchMove,
    required this.onBatchTag,
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
                      Expanded(
                        child: isMultiSelect
                            ? Text(l10n.selectedCount(selectedEntries.length), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))
                            : _BreadcrumbBar(breadcrumbs: breadcrumbs),
                      ),
                      const Spacer(),
                      if (isMultiSelect) ...[
                        _ToolbarButton(icon: Icons.close_rounded, tooltip: l10n.cancel, onPressed: onCancelSelection),
                        _ToolbarButton(icon: Icons.select_all_rounded, tooltip: l10n.selectAll, onPressed: onSelectAll),
                        _ToolbarButton(icon: Icons.delete_outline_rounded, tooltip: l10n.batchDelete, onPressed: selectedEntries.isNotEmpty ? onBatchDelete : null),
                        _ToolbarButton(icon: Icons.drive_file_move_rounded, tooltip: l10n.batchMove, onPressed: selectedEntries.isNotEmpty ? onBatchMove : null),
                        _ToolbarButton(icon: Icons.label_outline_rounded, tooltip: l10n.batchTag, onPressed: selectedEntries.isNotEmpty ? onBatchTag : null),
                      ] else ...[
                        _SortButton(sortOption: sortOption, onSortChanged: onSortChanged),
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
                              case 'batch_select': onToggleMultiSelect();
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
                          PopupMenuItem(value: 'batch_select', child: ListTile(leading: const Icon(Icons.checklist_rounded), title: Text(l10n.batchSelect), dense: true, contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'close', child: ListTile(leading: const Icon(Icons.close_rounded), title: Text(l10n.closeDatabase), dense: true, contentPadding: EdgeInsets.zero)),
                        ],
                      ),
                      ],
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
                    isMultiSelect: isMultiSelect,
                    selectedEntries: selectedEntries,
                    onToggleEntrySelection: onToggleEntrySelection,
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

class _SortButton extends StatelessWidget {
  final EntrySortOption sortOption;
  final ValueChanged<EntrySortOption> onSortChanged;
  const _SortButton({required this.sortOption, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<EntrySortOption>(
      tooltip: l10n.sortBy,
      icon: Icon(Icons.sort_rounded, size: 20, color: colorScheme.onSurfaceVariant),
      onSelected: onSortChanged,
      itemBuilder: (_) => [
        _sortItem(l10n.sortTitleAsc, EntrySortOption.titleAsc, Icons.sort_by_alpha_rounded),
        _sortItem(l10n.sortTitleDesc, EntrySortOption.titleDesc, Icons.sort_by_alpha_rounded),
        const PopupMenuDivider(),
        _sortItem(l10n.sortCreatedNewest, EntrySortOption.createdNewest, Icons.access_time_rounded),
        _sortItem(l10n.sortCreatedOldest, EntrySortOption.createdOldest, Icons.access_time_rounded),
        const PopupMenuDivider(),
        _sortItem(l10n.sortModifiedNewest, EntrySortOption.modifiedNewest, Icons.edit_rounded),
        _sortItem(l10n.sortModifiedOldest, EntrySortOption.modifiedOldest, Icons.edit_rounded),
        const PopupMenuDivider(),
        _sortItem(l10n.sortExpiredFirst, EntrySortOption.expiredFirst, Icons.warning_amber_rounded),
      ],
    );
  }

  PopupMenuItem<EntrySortOption> _sortItem(String label, EntrySortOption value, IconData icon) {
    final isSelected = sortOption == value;
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
        trailing: isSelected ? const Icon(Icons.check_rounded, size: 18) : null,
        dense: true,
        contentPadding: EdgeInsets.zero,
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
  final EntrySortOption sortOption;
  final ValueChanged<EntrySortOption> onSortChanged;
  final bool isMultiSelect;
  final Set<KdbxEntry> selectedEntries;
  final VoidCallback onToggleMultiSelect;
  final ValueChanged<KdbxEntry> onToggleEntrySelection;
  final VoidCallback onSelectAll;
  final VoidCallback onCancelSelection;
  final VoidCallback onBatchDelete;
  final VoidCallback onBatchMove;
  final VoidCallback onBatchTag;

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
    required this.sortOption,
    required this.onSortChanged,
    required this.isMultiSelect,
    required this.selectedEntries,
    required this.onToggleMultiSelect,
    required this.onToggleEntrySelection,
    required this.onSelectAll,
    required this.onCancelSelection,
    required this.onBatchDelete,
    required this.onBatchMove,
    required this.onBatchTag,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: isMultiSelect
            ? Text(l10n.selectedCount(selectedEntries.length))
            : _BreadcrumbBar(breadcrumbs: breadcrumbs),
        leading: isMultiSelect
            ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: onCancelSelection)
            : (onPop != null ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: onPop) : null),
        actions: isMultiSelect
            ? [
                IconButton(icon: const Icon(Icons.select_all_rounded), tooltip: l10n.selectAll, onPressed: onSelectAll),
                IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: l10n.batchDelete, onPressed: selectedEntries.isNotEmpty ? onBatchDelete : null),
                IconButton(icon: const Icon(Icons.drive_file_move_rounded), tooltip: l10n.batchMove, onPressed: selectedEntries.isNotEmpty ? onBatchMove : null),
                IconButton(icon: const Icon(Icons.label_outline_rounded), tooltip: l10n.batchTag, onPressed: selectedEntries.isNotEmpty ? onBatchTag : null),
              ]
            : [
              if (isOpenedFromCloud)
                IconButton(icon: const Icon(Icons.sync_rounded, size: 20), tooltip: l10n.syncFromCloud, onPressed: () => _syncFromCloud(context)),
              _SortButton(sortOption: sortOption, onSortChanged: onSortChanged),
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
                case 'batch_select': onToggleMultiSelect();
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
              PopupMenuItem(value: 'batch_select', child: ListTile(leading: const Icon(Icons.checklist_rounded), title: Text(l10n.batchSelect), dense: true, contentPadding: EdgeInsets.zero)),
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
              isMultiSelect: isMultiSelect,
              selectedEntries: selectedEntries,
              onToggleEntrySelection: onToggleEntrySelection,
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

