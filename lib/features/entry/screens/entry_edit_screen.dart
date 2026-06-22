import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/attachments_section.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../core/widgets/toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';
import '../../totp/data/totp_service.dart';
import '../../totp/widgets/totp_edit_sheet.dart';

const _standardKeys = {'Title', 'UserName', 'Password', 'URL', 'Notes'};

class EntryEditScreen extends ConsumerStatefulWidget {
  final String? entryUuid;
  final String groupPath;

  const EntryEditScreen({super.key, this.entryUuid, required this.groupPath});

  @override
  ConsumerState<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _CustomFieldData {
  String originalKey;
  final TextEditingController nameCtrl;
  final TextEditingController valueCtrl;
  final FocusNode nameFocus;
  bool protected;
  bool obscure;

  _CustomFieldData({
    required this.originalKey,
    required String name,
    required String value,
    this.protected = false,
  })  : nameCtrl = TextEditingController(text: name),
        valueCtrl = TextEditingController(text: value),
        nameFocus = FocusNode(),
        obscure = protected;

  void dispose() {
    nameCtrl.dispose();
    valueCtrl.dispose();
    nameFocus.dispose();
  }
}

class _EntryEditScreenState extends ConsumerState<EntryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_CustomFieldData> _customFields = [];
  bool _isEdit = false;
  KdbxEntry? _entry;
  bool _expires = false;
  DateTime? _expiryDate;
  TotpConfig? _totpConfig;
  final _totpService = TotpService();

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  void _loadEntry() {
    final service = ref.read(databaseServiceProvider);

    // Look up by UUID if provided
    if (widget.entryUuid != null && widget.entryUuid!.isNotEmpty) {
      final entry = service.findEntryByUuid(KdbxUuid.fromString(widget.entryUuid!));
      if (entry != null) {
        _titleCtrl.text = entry.fields['Title']?.text ?? '';
        _usernameCtrl.text = entry.fields['UserName']?.text ?? '';
        _passwordCtrl.text = entry.fields['Password']?.text ?? '';
        _urlCtrl.text = entry.fields['URL']?.text ?? '';
        _notesCtrl.text = entry.fields['Notes']?.text ?? '';
        _isEdit = true;
        _entry = entry;
        _expires = entry.times.expires;
        _expiryDate = entry.times.expiry.time;
        _totpConfig = _totpService.loadFromEntry(entry);
        _loadCustomFields(entry);
        return;
      }
    }

    // Create new entry
    final group = service.findGroupByPath(widget.groupPath);
    if (group != null) {
      _wasDirtyBeforeCreate = service.isDirty;
      _entry = service.createEntry(group);
    }
  }

  void _loadCustomFields(KdbxEntry entry) {
    for (final e in entry.fields.entries) {
      if (_standardKeys.contains(e.key)) continue;
      _customFields.add(_CustomFieldData(
        originalKey: e.key,
        name: e.key,
        value: e.value.text,
        protected: e.value is ProtectedTextField,
      ));
    }
  }

  bool _saved = false;
  bool _wasDirtyBeforeCreate = false;

  @override
  void dispose() {
    if (!_saved && !_isEdit && _entry != null) {
      final service = ref.read(databaseServiceProvider);
      final group = service.findGroupByPath(widget.groupPath);
      if (group != null) {
        group.entries.remove(_entry);
        service.rebuildEntryCache();
        if (!_wasDirtyBeforeCreate) {
          service.markClean();
        }
      }
    }
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    for (final f in _customFields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editEntry : l10n.newEntry),
        actions: [
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Basic info card
            _SectionCard(
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.title,
                    prefixIcon: const Icon(Icons.title_rounded),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Password card
            _SectionCard(
              children: [
                PasswordTextField(
                  controller: _passwordCtrl,
                  labelText: l10n.password,
                  showStrengthIndicator: true,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final password = await showPasswordGeneratorDialog(context);
                      if (password != null) {
                        _passwordCtrl.text = password;
                      }
                    },
                    icon: const Icon(Icons.casino_outlined, size: 16),
                    label: Text(l10n.generatePassword),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Details card
            _SectionCard(
              children: [
                TextFormField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.url,
                    prefixIcon: const Icon(Icons.link_rounded),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.notes,
                    prefixIcon: const Icon(Icons.note_outlined),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
            // Expiration
            const SizedBox(height: 12),
            _SectionCard(
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(l10n.expiration, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    ),
                    Switch(
                      value: _expires,
                      onChanged: (v) => setState(() {
                        _expires = v;
                        if (v && _expiryDate == null) {
                          _expiryDate = DateTime.now().add(const Duration(days: 30));
                        }
                      }),
                    ),
                  ],
                ),
                if (_expires) ...[
                  Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _expiryDate != null
                                  ? '${_expiryDate!.year}-${_expiryDate!.month.toString().padLeft(2, '0')}-${_expiryDate!.day.toString().padLeft(2, '0')}'
                                  : l10n.noExpiration,
                              style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                            ),
                          ),
                          if (_expiryDate != null)
                            IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                              onPressed: () => setState(() => _expiryDate = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Custom fields
            if (_entry != null) ...[
              const SizedBox(height: 12),
              _buildCustomFieldsSection(colorScheme, l10n),
            ],
            // TOTP
            if (_entry != null) ...[
              const SizedBox(height: 12),
              _buildTotpSection(colorScheme, l10n),
            ],
            // Attachments
            if (_entry != null) ...[
              const SizedBox(height: 4),
              _AttachmentsSectionWrapper(
                entry: _entry!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotpSection(ColorScheme colorScheme, AppLocalizations l10n) {
    return _SectionCard(
      children: [
        Row(
          children: [
            Icon(Icons.timer_outlined, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'TOTP',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
            ),
            if (_totpConfig != null)
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
                tooltip: l10n.deleteTotp,
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.deleteTotp),
                      content: Text(l10n.deleteTotpConfirm),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.error,
                            foregroundColor: Theme.of(ctx).colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) setState(() => _totpConfig = null);
                },
              ),
          ],
        ),
        Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
        if (_totpConfig != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.totpSecretLabel}: ${_totpConfig!.secret.substring(0, _totpConfig!.secret.length > 8 ? 8 : _totpConfig!.secret.length)}...',
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_totpConfig!.digits} digits / ${_totpConfig!.period}s / ${_totpConfig!.algorithm}',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final result = await showTotpEditSheet(context, initial: _totpConfig);
                    if (result != null) setState(() => _totpConfig = result.config);
                  },
                  child: Text(l10n.edit),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final result = await showTotpEditSheet(context);
                  if (result != null) setState(() => _totpConfig = result.config);
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(l10n.setupTotp),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomFieldsSection(ColorScheme colorScheme, AppLocalizations l10n) {
    return _SectionCard(
      children: [
        for (int i = 0; i < _customFields.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
          _buildCustomFieldRow(_customFields[i], colorScheme, l10n),
        ],
        if (_customFields.isNotEmpty)
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _addCustomField,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(l10n.addCustomField),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomFieldRow(_CustomFieldData field, ColorScheme colorScheme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Field name
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: field.nameCtrl,
              focusNode: field.nameFocus,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
            ),
          ),
          const SizedBox(width: 8),
          // Field value
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: field.valueCtrl,
              obscureText: field.obscure,
              decoration: InputDecoration(
                labelText: l10n.fieldValue,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
                suffixIcon: field.protected
                    ? IconButton(
                        icon: Icon(
                          field.obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18,
                        ),
                        onPressed: () => setState(() => field.obscure = !field.obscure),
                      )
                    : null,
              ),
            ),
          ),
          // Protect toggle
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(
                field.protected ? Icons.shield_rounded : Icons.shield_outlined,
                size: 18,
                color: field.protected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              tooltip: field.protected ? l10n.unprotectField : l10n.protectField,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() {
                field.protected = !field.protected;
                field.obscure = field.protected;
              }),
            ),
          ),
          // Delete
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error),
              padding: EdgeInsets.zero,
              onPressed: () => _deleteCustomField(field),
            ),
          ),
        ],
      ),
    );
  }

  void _addCustomField() {
    final field = _CustomFieldData(originalKey: '', name: '', value: '');
    setState(() => _customFields.add(field));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      field.nameFocus.requestFocus();
    });
  }

  Future<void> _deleteCustomField(_CustomFieldData field) async {
    final l10n = AppLocalizations.of(context)!;
    if (field.valueCtrl.text.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.delete),
          content: Text(l10n.deleteCustomFieldConfirm(field.nameCtrl.text)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() {
      _customFields.remove(field);
      field.dispose();
    });
  }

  void _save() {
    // Custom field validation is done below; no form-level validators to check.
    if (_entry == null) return;

    final l10n = AppLocalizations.of(context)!;

    // Validate custom field names
    final names = <String>{};
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      if (name.isEmpty) {
        showToast(context, l10n.fieldNameEmpty, isError: true);
        return;
      }
      if (_standardKeys.contains(name)) {
        showToast(context, l10n.fieldNameReserved(name), isError: true);
        return;
      }
      if (!names.add(name)) {
        showToast(context, l10n.fieldNameDuplicate(name), isError: true);
        return;
      }
    }

    final service = ref.read(databaseServiceProvider);

    if (_isEdit) {
      _entry!.times.touch();
      _entry!.pushHistory();
    }
    _entry!.times.expires = _expires;
    _entry!.times.expiry = KdbxTime(_expires ? _expiryDate : null);
    _entry!.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
    _entry!.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
    _entry!.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
    _entry!.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
    _entry!.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);

    // Save custom fields
    final currentKeys = names;
    final keysToRemove = _entry!.fields.keys
        .where((k) => !_standardKeys.contains(k) && !currentKeys.contains(k))
        .toList();
    for (final key in keysToRemove) {
      _entry!.fields.remove(key);
    }

    // Remove old keys first (separate pass to avoid data loss on field rename swaps)
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      if (f.originalKey.isNotEmpty && f.originalKey != name) {
        _entry!.fields.remove(f.originalKey);
      }
    }
    for (final f in _customFields) {
      final name = f.nameCtrl.text.trim();
      _entry!.fields[name] = KdbxTextField.fromText(
        text: f.valueCtrl.text,
        protected: f.protected,
      );
    }

    // Save TOTP
    if (_totpConfig != null) {
      _totpService.saveToEntry(_entry!, _totpConfig!);
    } else if (_isEdit) {
      _totpService.removeFromEntry(_entry!);
    }

    _saved = true;
    service.markDirty();
    refreshExplorerLists(ref);
    if (mounted) context.pop();
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: ClayDecoration.card(brightness: brightness, radius: 18),
      child: Column(
        children: children,
      ),
    );
  }
}

class _AttachmentsSectionWrapper extends ConsumerStatefulWidget {
  final KdbxEntry entry;

  const _AttachmentsSectionWrapper({required this.entry});

  @override
  ConsumerState<_AttachmentsSectionWrapper> createState() => _AttachmentsSectionWrapperState();
}

class _AttachmentsSectionWrapperState extends ConsumerState<_AttachmentsSectionWrapper> {
  @override
  Widget build(BuildContext context) {
    final service = ref.read(databaseServiceProvider);
    return AttachmentsSection(
      entry: widget.entry,
      service: service,
      onChanged: () => setState(() {}),
    );
  }
}
