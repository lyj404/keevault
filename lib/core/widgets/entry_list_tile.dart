import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';
import '../theme/app_theme.dart';
import '../utils/clipboard_utils.dart';
import '../../features/totp/data/totp_service.dart';
import '../../l10n/app_localizations.dart';
import 'toast.dart';
import '../utils/fuzzy_match.dart';

class EntryListTile extends StatelessWidget {
  final KdbxEntry entry;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;
  final VoidCallback? onMove;
  final String? query;
  final bool showCheckbox;
  final bool isChecked;
  final bool draggable;

  static final _totpService = TotpService();

  const EntryListTile({super.key, required this.entry, this.isSelected = false, this.onTap, this.onOpen, this.onDelete, this.onRestore, this.onMove, this.query, this.showCheckbox = false, this.isChecked = false, this.draggable = false});

  String get _title => entry.fields['Title']?.text ?? '';
  String get _username => entry.fields['UserName']?.text ?? '';
  String get _password => entry.fields['Password']?.text ?? '';
  bool get _isExpired => entry.times.expires && entry.times.expiry.time != null && entry.times.expiry.time!.isBefore(DateTime.now());

  String? _getTotpCode() {
    final config = _totpService.loadFromEntry(entry);
    if (config == null) return null;
    return _totpService.generateCode(config);
  }


  Widget _highlightedTitle(String text, ColorScheme colorScheme) {
    if (query == null || query!.isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface),
      );
    }
    final match = fuzzyMatch(text, query!);
    if (match == null || !match.isMatch) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface),
      );
    }
    final positions = match.positions.toSet();
    final normalStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.onSurface);
    final highlightStyle = TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colorScheme.primary, backgroundColor: colorScheme.primaryContainer);
    final spans = <TextSpan>[];
    for (int i = 0; i < text.length; i++) {
      spans.add(TextSpan(
        text: text[i],
        style: positions.contains(i) ? highlightStyle : normalStyle,
      ));
    }
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

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
    final url = entry.fields['URL']?.text ?? '';
    if (url.isNotEmpty) {
      items.add(PopupMenuItem(
        value: 'copy_url',
        child: ListTile(leading: const Icon(Icons.link_rounded), title: Text(l10n.copyUrl), dense: true, contentPadding: EdgeInsets.zero),
      ));
    }
    final hasTotp = entry.customData?.map['TimeOtp-Secret']?.value != null;
    if (hasTotp) {
      items.add(PopupMenuItem(
        value: 'copy_totp',
        child: ListTile(leading: const Icon(Icons.timer_rounded), title: Text(l10n.copyTotp), dense: true, contentPadding: EdgeInsets.zero),
      ));
    }
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
        case 'copy_url':
          copyToClipboardWithAutoClear(entry.fields['URL']?.text ?? '');
          showToast(context, l10n.copiedUrl);
        case 'copy_totp':
          final totpCode = _getTotpCode();
          if (totpCode != null) {
            copyToClipboardWithAutoClear(totpCode);
            showToast(context, l10n.copiedTotp);
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

    final tile = Padding(
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
                  // Checkbox for multi-select mode
                  if (showCheckbox) ...[
                    Checkbox(
                      value: isChecked,
                      onChanged: onTap != null ? (_) => onTap!() : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                  ],
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
                        _highlightedTitle(displayTitle, colorScheme),
                        if (_username.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        if (entry.tags != null && entry.tags!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final tag in entry.tags!)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Expired badge – aligned with buttons
                  if (_isExpired) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_rounded, size: 12, color: colorScheme.error),
                          const SizedBox(width: 3),
                          Text(
                            l10n.expired,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
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

    if (!draggable) return tile;

    return LongPressDraggable<KdbxEntry>(
      data: entry,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIcon(entry.icon), size: 18, color: colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
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
