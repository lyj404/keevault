import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kpasslib/kpasslib.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/password_text_field.dart';
import '../../../core/widgets/password_generator_dialog.dart';
import '../../../l10n/app_localizations.dart';
import '../../database/providers/database_provider.dart';
import '../../explorer/providers/explorer_provider.dart';

class EntryEditScreen extends ConsumerStatefulWidget {
  final int? entryIndex;
  final String groupPath;

  const EntryEditScreen({super.key, this.entryIndex, required this.groupPath});

  @override
  ConsumerState<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends ConsumerState<EntryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  void _loadEntry() {
    final service = ref.read(databaseServiceProvider);
    final group = service.findGroupByPath(widget.groupPath);
    if (group != null && widget.entryIndex != null && widget.entryIndex! < group.entries.length) {
      final entry = group.entries[widget.entryIndex!];
      _titleCtrl.text = entry.fields['Title']?.text ?? '';
      _usernameCtrl.text = entry.fields['UserName']?.text ?? '';
      _passwordCtrl.text = entry.fields['Password']?.text ?? '';
      _urlCtrl.text = entry.fields['URL']?.text ?? '';
      _notesCtrl.text = entry.fields['Notes']?.text ?? '';
      _isEdit = true;
    }
  }

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
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final service = ref.read(databaseServiceProvider);
    final db = service.db;
    if (db == null) return;

    final group = service.findGroupByPath(widget.groupPath);
    if (group == null) return;

    if (_isEdit && widget.entryIndex != null && widget.entryIndex! < group.entries.length) {
      final entry = group.entries[widget.entryIndex!];
      entry.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
      entry.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
      entry.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
      entry.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
      entry.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);
      entry.pushHistory();
    } else {
      final entry = service.createEntry(group);
      entry.fields['Title'] = KdbxTextField.fromText(text: _titleCtrl.text);
      entry.fields['UserName'] = KdbxTextField.fromText(text: _usernameCtrl.text);
      entry.fields['Password'] = KdbxTextField.fromText(text: _passwordCtrl.text, protected: true);
      entry.fields['URL'] = KdbxTextField.fromText(text: _urlCtrl.text);
      entry.fields['Notes'] = KdbxTextField.fromText(text: _notesCtrl.text);
    }

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
