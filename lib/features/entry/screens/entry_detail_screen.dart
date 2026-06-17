import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/move_to_group_dialog.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

class EntryDetailScreen extends ConsumerWidget {
  final int entryIndex;
  final String groupPath;

  const EntryDetailScreen({super.key, required this.entryIndex, required this.groupPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(databaseServiceProvider);
    final group = service.findGroupByPath(groupPath);
    final l10n = AppLocalizations.of(context)!;

    if (group == null || entryIndex < 0 || entryIndex >= group.entries.length) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.entry)),
        body: EmptyState(icon: Icons.error_outline_rounded, message: l10n.entryNotFound),
      );
    }

    final entry = group.entries[entryIndex];
    final title = entry.fields['Title']?.text ?? '';
    final colorScheme = Theme.of(context).colorScheme;
    final isInRecycleBin = group.icon == KdbxIcon.trashBin;

    return Scaffold(
      appBar: AppBar(
        title: Text(title.isEmpty ? l10n.entryDetail : title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (isInRecycleBin)
            IconButton(
              icon: Icon(Icons.restore_rounded, size: 20, color: colorScheme.primary),
              tooltip: l10n.restore,
              onPressed: () => _restoreEntry(context, ref, entry),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.history_rounded, size: 20),
              tooltip: l10n.history,
              onPressed: () => context.push('/entry/history?index=$entryIndex&groupPath=${Uri.encodeComponent(groupPath)}'),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              tooltip: l10n.edit,
              onPressed: () => context.push('/entry/edit?index=$entryIndex&groupPath=${Uri.encodeComponent(groupPath)}'),
            ),
            IconButton(
              icon: const Icon(Icons.drive_file_move_rounded, size: 20),
              tooltip: l10n.move,
              onPressed: () => _moveEntry(context, ref, entry, group),
            ),
          ],
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.error),
            tooltip: isInRecycleBin ? l10n.permanentDelete : l10n.delete,
            onPressed: () => isInRecycleBin
                ? _permanentDeleteEntry(context, ref, entry)
                : _deleteEntry(context, ref, entry, group),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Title card
          if (title.isNotEmpty)
            _SectionCard(
              children: [
                _FieldRow(label: l10n.title, value: title),
              ],
            ),
          // Credentials card
          _SectionCard(
            children: [
              _FieldRow(label: l10n.username, value: entry.fields['UserName']?.text ?? '', showCopy: true),
              _PasswordField(value: entry.fields['Password']?.text ?? ''),
            ],
          ),
          // Details card
          if ((entry.fields['URL']?.text ?? '').isNotEmpty || (entry.fields['Notes']?.text ?? '').isNotEmpty)
            _SectionCard(
              children: [
                _FieldRow(label: l10n.url, value: entry.fields['URL']?.text ?? '', showCopy: true),
                _FieldRow(label: l10n.notes, value: entry.fields['Notes']?.text ?? '', multiline: true),
              ],
            ),
          // Custom fields
          ...() {
            final custom = entry.fields.entries
                .where((e) => !['Title', 'UserName', 'Password', 'URL', 'Notes'].contains(e.key))
                .toList();
            if (custom.isEmpty) return <Widget>[];
            return [
              _SectionCard(
                children: [
                  for (final e in custom)
                    _FieldRow(label: e.key, value: e.value.text, showCopy: true),
                ],
              ),
            ];
          }(),
        ],
      ),
    );
  }

  void _deleteEntry(BuildContext context, WidgetRef ref, KdbxEntry entry, KdbxGroup group) {
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
              if (context.mounted) {
                showToast(context, l10n.movedToRecycleBin);
                context.pop();
              }
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
              if (context.mounted) {
                showToast(context, l10n.permanentlyDeleted);
                context.pop();
              }
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
      if (context.mounted) {
        showToast(context, l10n.restored);
        context.pop();
      }
    } else {
      if (context.mounted) {
        showToast(context, l10n.restoreFailed, isError: true);
      }
    }
  }

  Future<void> _moveEntry(BuildContext context, WidgetRef ref, KdbxEntry entry, KdbxGroup currentGroup) async {
    final db = ref.read(databaseServiceProvider).db;
    if (db == null) return;
    final target = await showMoveToGroupDialog(context, db: db, excludeGroup: currentGroup);
    if (target == null) return;
    ref.read(databaseServiceProvider).moveItem(entry, target);
    refreshExplorerLists(ref);
    final l10n = AppLocalizations.of(context)!;
    if (context.mounted) {
      showToast(context, l10n.moved);
      context.pop();
    }
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final visibleChildren = children.where((c) {
      if (c is _FieldRow && c.value.isEmpty) return false;
      if (c is _PasswordField && c.value.isEmpty) return false;
      return true;
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: ClayDecoration.card(brightness: brightness, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < visibleChildren.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15),
                ),
              ),
            visibleChildren[i],
          ],
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showCopy;
  final bool multiline;

  const _FieldRow({required this.label, required this.value, this.showCopy = false, this.multiline = false});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
              if (showCopy) ...[
                const Spacer(),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 15),
                    tooltip: l10n.copy,
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      copyToClipboardWithAutoClear(value);
                      showToast(context, l10n.copiedField(label));
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: multiline ? 1.5 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final String value;
  const _PasswordField({required this.value});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    if (widget.value.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.password,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  icon: Icon(_visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 15),
                  tooltip: _visible ? l10n.hide : l10n.show,
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  tooltip: l10n.copy,
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    copyToClipboardWithAutoClear(widget.value);
                    showToast(context, l10n.copiedPassword);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            _visible ? widget.value : '•' * widget.value.length,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: _visible ? null : 'monospace',
              letterSpacing: _visible ? null : 2,
            ),
          ),
        ],
      ),
    );
  }
}
