part of 'explorer_screen.dart';

class _BreadcrumbBar extends ConsumerWidget {
  final List<String> breadcrumbs;
  const _BreadcrumbBar({required this.breadcrumbs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(databaseServiceProvider);
    final recycleBinName = service.recycleBinName;
    final displayNames = [
      for (final b in breadcrumbs)
        if (b == 'Root')
          l10n.rootDirectory
        else if (recycleBinName != null && b == recycleBinName)
          l10n.recycleBin
        else
          b,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < displayNames.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: colorScheme.outline,
                ),
              ),
            Text(
              displayNames[i],
              style: TextStyle(
                fontSize: 14,
                fontWeight: i == displayNames.length - 1
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: i == displayNames.length - 1
                    ? null
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
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
      return EmptyState(
        icon: Icons.folder_open_rounded,
        message: AppLocalizations.of(context)!.thisGroupIsEmpty,
      );
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
            onTap: isMultiSelect
                ? () => onToggleEntrySelection(e)
                : () => onEntrySelect(e),
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
      return EmptyState(
        icon: Icons.folder_open_rounded,
        message: l10n.thisGroupIsEmpty,
      );
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
            onTap: isMultiSelect
                ? () => onToggleEntrySelection(e)
                : () => onEntrySelect(e),
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

  const _MobileGroupTile({
    required this.group,
    required this.onTap,
    this.onDeleteGroup,
    this.onRenameGroup,
    this.onRestoreGroup,
    this.onPermanentDeleteGroup,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMenu =
        onDeleteGroup != null ||
        onRenameGroup != null ||
        onRestoreGroup != null ||
        onPermanentDeleteGroup != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: isDark
            ? ClayColors.surfaceCardDark
            : ClayColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          onLongPress: hasMenu
              ? () {
                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
                  final size = box?.size ?? Size.zero;
                  _showContextMenu(
                    context,
                    Offset(pos.dx + size.width / 2, pos.dy + size.height / 2),
                  );
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
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
    if (group.groups.isNotEmpty) {
      parts.add('${group.groups.length} ${l10n.groups}');
    }
    if (group.entries.isNotEmpty) {
      parts.add('${group.entries.length} ${l10n.entries}');
    }
    return parts.join(' · ');
  }

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
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
            child: ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.rename),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onDeleteGroup != null)
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.deleteGroup),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onRestoreGroup != null)
          PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: Text(l10n.restore),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        if (onPermanentDeleteGroup != null)
          PopupMenuItem(
            value: 'permanent_delete',
            child: ListTile(
              leading: const Icon(Icons.delete_forever_rounded),
              title: Text(l10n.permanentDelete),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
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

// ─── Mobile TOTP tab ────────────────────────────────────────────────────

class _MobileTotpTab extends ConsumerStatefulWidget {
  final ValueChanged<KdbxEntry> onEntryOpen;
  final TotpService totpService;

  const _MobileTotpTab({
    super.key,
    required this.onEntryOpen,
    required this.totpService,
  });

  @override
  ConsumerState<_MobileTotpTab> createState() => _MobileTotpTabState();
}

class _MobileTotpTabState extends ConsumerState<_MobileTotpTab> {
  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _query = '';
      }
    });
  }

  Future<void> addTotpEntry(BuildContext context) async {
    final result = await showTotpEditSheet(context);
    if (result == null || !context.mounted) return;

    final service = ref.read(databaseServiceProvider);
    const groupPath = 'TOTP';
    final root = service.findGroupByPath('');
    if (root == null) return;
    final group =
        service.findGroupByPath(groupPath) ??
        service.createGroup(root, groupPath);
    final entry = service.createEntry(group);
    entry.fields['Title'] = KdbxTextField.fromText(text: result.title);
    widget.totpService.saveToEntry(entry, result.config);
    service.markDirty();
    refreshExplorerLists(ref);

    // The TOTP tab already shows the new item. Avoid pushing another route
    // after the scanner and bottom sheet close; this caused a grey page on
    // some Android devices.
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(databaseServiceProvider);
    final allEntries = service.allEntries;
    final l10n = AppLocalizations.of(context)!;

    final totpEntries = <_TotpEntryInfo>[];
    for (final entry in allEntries) {
      final config = widget.totpService.loadFromEntry(entry);
      if (config == null) continue;
      if (_query.isNotEmpty) {
        final title = entry.fields['Title']?.text ?? '';
        final username = entry.fields['UserName']?.text ?? '';
        final q = _query.toLowerCase();
        if (!title.toLowerCase().contains(q) &&
            !username.toLowerCase().contains(q)) {
          continue;
        }
      }
      totpEntries.add(_TotpEntryInfo(entry: entry, config: config));
    }

    return Column(
      children: [
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _query = '';
                      _searching = false;
                    });
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        Expanded(
          child: totpEntries.isEmpty
              ? EmptyState(
                  icon: Icons.timer_outlined,
                  message: l10n.noTotpEntries,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: totpEntries.length,
                  itemBuilder: (context, index) {
                    final info = totpEntries[index];
                    return _TotpListTile(
                      entry: info.entry,
                      config: info.config,
                      totpService: widget.totpService,
                      onTap: () => widget.onEntryOpen(info.entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _TotpEntryInfo {
  final KdbxEntry entry;
  final TotpConfig config;
  const _TotpEntryInfo({required this.entry, required this.config});
}

class _TotpListTile extends StatefulWidget {
  final KdbxEntry entry;
  final TotpConfig config;
  final TotpService totpService;
  final VoidCallback onTap;

  const _TotpListTile({
    required this.entry,
    required this.config,
    required this.totpService,
    required this.onTap,
  });

  @override
  State<_TotpListTile> createState() => _TotpListTileState();
}

class _TotpListTileState extends State<_TotpListTile> {
  String _code = '';
  int _remaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateCode();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateCode());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCode() {
    final newCode = widget.totpService.generateCode(widget.config);
    final newRemaining = widget.totpService.remainingSeconds(widget.config);
    if (mounted && (newCode != _code || newRemaining != _remaining)) {
      setState(() {
        _code = newCode;
        _remaining = newRemaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final title = widget.entry.fields['Title']?.text ?? l10n.untitled;
    final isLow = _remaining <= 5;
    final progress = _remaining / widget.config.period;
    final codeDisplay = _code.length == 6
        ? '${_code.substring(0, 3)} ${_code.substring(3)}'
        : _code;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: isDark
            ? ClayColors.surfaceCardDark
            : ClayColors.surfaceCardLight,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: ClayDecoration.iconContainer(
                        brightness: brightness,
                        radius: 11,
                      ),
                      child: Icon(
                        Icons.timer_rounded,
                        size: 18,
                        color: isLow ? colorScheme.error : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SizedBox(width: 48),
                    Text(
                      codeDisplay,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isLow
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            backgroundColor: colorScheme.outlineVariant
                                .withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isLow ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                          Text(
                            '$_remaining',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: isLow
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            copyToClipboardWithAutoClear(_code);
                            showToast(context, l10n.copiedTotp);
                          },
                          child: Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Mobile search tab ──────────────────────────────────────────────────

class _MobileSearchTab extends ConsumerWidget {
  final ValueChanged<KdbxEntry> onEntryOpen;

  const _MobileSearchTab({required this.onEntryOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final service = ref.read(databaseServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_rounded,
        message: l10n.enterKeywords,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final result = results[i];
        final entry = result.entry;
        final groupPath = entry.parent != null
            ? service.getGroupPath(entry.parent!)
            : '';
        return RepaintBoundary(
          child: EntryListTile(
            key: ValueKey(entry.uuid),
            entry: entry,
            onTap: () {},
            onOpen: () {
              final encodedUuid = Uri.encodeComponent(entry.uuid.string);
              context.push(
                '/entry/detail?uuid=$encodedUuid&groupPath=${Uri.encodeComponent(groupPath)}',
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Mobile tools tab ───────────────────────────────────────────────────

class _MobileToolsPanel extends StatelessWidget {
  final bool isOpenedFromCloud;
  final bool isCloudOfflineMode;
  final String? cloudOfflineReason;
  final VoidCallback onClose;
  final VoidCallback? onImportCsv;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportKdbx;

  const _MobileToolsPanel({
    required this.isOpenedFromCloud,
    required this.isCloudOfflineMode,
    this.cloudOfflineReason,
    required this.onClose,
    this.onImportCsv,
    this.onExportCsv,
    this.onExportKdbx,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOpenedFromCloud && isCloudOfflineMode) ...[
            _ToolsSection(
              brightness: brightness,
              title: l10n.cloudDatabase,
              children: [
                _ToolTile(
                  icon: Icons.cloud_off_rounded,
                  iconBg: colorScheme.tertiaryContainer,
                  iconColor: colorScheme.tertiary,
                  title: cloudOfflineReason ?? l10n.downloadingFromCloud,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (isOpenedFromCloud) ...[
            const SizedBox(height: 16),
            _ToolsSection(
              brightness: brightness,
              title: l10n.webdavSync,
              children: [
                _ToolTile(
                  icon: Icons.cloud_upload_rounded,
                  iconBg: colorScheme.surfaceContainerLow,
                  iconColor: colorScheme.onSurfaceVariant,
                  title: l10n.syncToCloud,
                  onTap: () => _syncToCloud(context),
                ),
                _ToolTile(
                  icon: Icons.cloud_download_rounded,
                  iconBg: colorScheme.surfaceContainerLow,
                  iconColor: colorScheme.onSurfaceVariant,
                  title: l10n.syncFromCloud,
                  onTap: () => _syncFromCloud(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _ToolsSection(
            brightness: brightness,
            title: l10n.importCsv,
            children: [
              if (onImportCsv != null)
                _ToolTile(
                  icon: Icons.file_upload_rounded,
                  iconBg: colorScheme.surfaceContainerLow,
                  iconColor: colorScheme.onSurfaceVariant,
                  title: l10n.importCsv,
                  onTap: onImportCsv!,
                ),
              if (onExportCsv != null)
                _ToolTile(
                  icon: Icons.file_download_rounded,
                  iconBg: colorScheme.surfaceContainerLow,
                  iconColor: colorScheme.onSurfaceVariant,
                  title: l10n.exportCsv,
                  onTap: onExportCsv!,
                ),
              if (onExportKdbx != null)
                _ToolTile(
                  icon: Icons.save_as_rounded,
                  iconBg: colorScheme.surfaceContainerLow,
                  iconColor: colorScheme.onSurfaceVariant,
                  title: l10n.exportKdbx,
                  onTap: onExportKdbx!,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ToolsSection(
            brightness: brightness,
            title: l10n.settings,
            children: [
              _ToolTile(
                icon: Icons.settings_rounded,
                iconBg: colorScheme.surfaceContainerLow,
                iconColor: colorScheme.onSurfaceVariant,
                title: l10n.settings,
                onTap: () => context.push('/settings'),
              ),
              _ToolTile(
                icon: Icons.info_outline_rounded,
                iconBg: colorScheme.surfaceContainerLow,
                iconColor: colorScheme.onSurfaceVariant,
                title: l10n.about,
                onTap: () => context.push('/about'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ToolsSection(
            brightness: brightness,
            title: l10n.closeDatabase,
            children: [
              _ToolTile(
                icon: Icons.close_rounded,
                iconBg: colorScheme.errorContainer,
                iconColor: colorScheme.onErrorContainer,
                title: l10n.closeDatabase,
                onTap: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolsSection extends StatelessWidget {
  final Brightness brightness;
  final String title;
  final List<Widget> children;

  const _ToolsSection({
    required this.brightness,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: ClayDecoration.card(brightness: brightness, radius: 16),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  const _ToolTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add entry bottom sheet ──────────────────────────────────────────────
