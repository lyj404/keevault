import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_utils.dart';
import '../../l10n/app_localizations.dart';
import 'toast.dart';

class EntryListTile extends StatelessWidget {
  final KdbxEntry entry;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onMove;

  const EntryListTile({super.key, required this.entry, this.isSelected = false, this.onTap, this.onOpen, this.onDelete, this.onRestore, this.onMove});

  String get _title => entry.fields['Title']?.text ?? '';
  String get _username => entry.fields['UserName']?.text ?? '';
  String get _password => entry.fields['Password']?.text ?? '';

  void _showContextMenu(BuildContext context, Offset globalPos) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final screenSize = overlay.size;
    final position = RelativeRect.fromLTRB(
      globalPos.dx,
      globalPos.dy,
      screenSize.width - globalPos.dx,
      screenSize.height - globalPos.dy,
    );
    final l10n = AppLocalizations.of(context)!;
    final items = <PopupMenuEntry<String>>[
      PopupMenuItem(
        value: 'copy_password',
        child: ListTile(leading: const Icon(Icons.copy_rounded), title: Text(l10n.copyPassword), dense: true, contentPadding: EdgeInsets.zero),
      ),
      PopupMenuItem(
        value: 'copy_username',
        child: ListTile(leading: const Icon(Icons.person_rounded), title: Text(l10n.copyUsername), dense: true, contentPadding: EdgeInsets.zero),
      ),
    ];
    if (onMove != null) {
      items.add(PopupMenuItem(
        value: 'move',
        child: ListTile(leading: const Icon(Icons.drive_file_move_rounded), title: Text(l10n.move), dense: true, contentPadding: EdgeInsets.zero),
      ));
    }
    if (onRestore != null) {
      items.add(PopupMenuItem(
        value: 'restore',
        child: ListTile(leading: const Icon(Icons.restore_rounded), title: Text(l10n.restore), dense: true, contentPadding: EdgeInsets.zero),
      ));
    }
    if (onDelete != null) {
      items.add(PopupMenuItem(
        value: 'delete',
        child: ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(onRestore != null ? l10n.permanentDelete : l10n.delete), dense: true, contentPadding: EdgeInsets.zero),
      ));
    }
    showMenu<String>(context: context, position: position, items: items).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'copy_password':
          copyToClipboardWithAutoClear(_password);
          showToast(context, l10n.copiedPassword);
        case 'copy_username':
          if (_username.isNotEmpty) {
            copyToClipboardWithAutoClear(_username);
            showToast(context, l10n.copiedUsername);
          }
        case 'move':
          onMove?.call();
        case 'restore':
          onRestore?.call();
        case 'delete':
          onDelete?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final l10n = AppLocalizations.of(context)!;
    final displayTitle = _title.isEmpty ? l10n.untitled : _title;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: brightness == Brightness.dark ? 0.15 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : ClayDecoration.card(
                brightness: brightness,
                radius: 16,
              ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
            onLongPress: () {
              final box = context.findRenderObject() as RenderBox?;
              final pos = box?.localToGlobal(Offset.zero) ?? Offset.zero;
              final size = box?.size ?? Size.zero;
              _showContextMenu(context, Offset(pos.dx + size.width / 2, pos.dy + size.height / 2));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Clay icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: ClayDecoration.iconContainer(
                      brightness: brightness,
                      radius: 13,
                    ),
                    child: Icon(_getIcon(entry.icon), size: 20, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface),
                        ),
                        if (_username.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Copy password button – clay style
                  if (_password.isNotEmpty)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            copyToClipboardWithAutoClear(_password);
                            showToast(context, l10n.copiedPassword);
                          },
                          child: Icon(Icons.copy_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  // Open detail button
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onOpen,
                        child: Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant),
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
}

IconData _getIcon(KdbxIcon icon) {
  return switch (icon) {
    KdbxIcon.key => Icons.key_rounded,
    KdbxIcon.world => Icons.language_rounded,
    KdbxIcon.networkServer => Icons.dns_rounded,
    KdbxIcon.eMail || KdbxIcon.eMailBox || KdbxIcon.eMailSearch => Icons.email_rounded,
    KdbxIcon.userCommunication || KdbxIcon.identity => Icons.person_rounded,
    KdbxIcon.homebanking || KdbxIcon.money => Icons.account_balance_rounded,
    KdbxIcon.certificate => Icons.verified_rounded,
    KdbxIcon.terminalEncrypted || KdbxIcon.console => Icons.terminal_rounded,
    KdbxIcon.drive || KdbxIcon.driveWindows || KdbxIcon.disk => Icons.storage_rounded,
    KdbxIcon.clipboardReady => Icons.content_paste_rounded,
    KdbxIcon.note || KdbxIcon.notepad => Icons.note_rounded,
    KdbxIcon.settings || KdbxIcon.configuration => Icons.settings_rounded,
    KdbxIcon.star => Icons.star_rounded,
    KdbxIcon.tool => Icons.build_rounded,
    KdbxIcon.home => Icons.home_rounded,
    KdbxIcon.book => Icons.book_rounded,
    KdbxIcon.list => Icons.list_rounded,
    KdbxIcon.package => Icons.inventory_2_rounded,
    KdbxIcon.clock => Icons.access_time_rounded,
    KdbxIcon.trashBin => Icons.delete_rounded,
    _ => Icons.key_rounded,
  };
}
