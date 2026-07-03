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

