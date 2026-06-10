import 'package:flutter/material.dart';
import 'package:kpasslib/kpasslib.dart';

/// Shows a dialog to pick a target group from the group tree.
/// Returns the selected [KdbxGroup] on confirm, or null if cancelled.
Future<KdbxGroup?> showMoveToGroupDialog(BuildContext context, {required KdbxDatabase db, KdbxGroup? excludeGroup}) async {
  return showDialog<KdbxGroup>(
    context: context,
    builder: (_) => _MoveToGroupDialog(db: db, excludeGroup: excludeGroup),
  );
}

class _MoveToGroupDialog extends StatefulWidget {
  final KdbxDatabase db;
  final KdbxGroup? excludeGroup;

  const _MoveToGroupDialog({required this.db, this.excludeGroup});

  @override
  State<_MoveToGroupDialog> createState() => _MoveToGroupDialogState();
}

class _MoveToGroupDialogState extends State<_MoveToGroupDialog> {
  KdbxGroup? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('移动到分组'),
      content: SizedBox(
        width: 360,
        height: 400,
        child: ListView(
          children: [
            _buildGroupTile(widget.db.root, 0),
            ..._buildChildren(widget.db.root, 1),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _selected != null ? () => Navigator.pop(context, _selected) : null,
          child: const Text('移动'),
        ),
      ],
    );
  }

  List<Widget> _buildChildren(KdbxGroup group, int depth) {
    final widgets = <Widget>[];
    for (final child in group.groups) {
      if (child == widget.excludeGroup) continue;
      if (child.icon == KdbxIcon.trashBin) continue;
      widgets.add(_buildGroupTile(child, depth));
      widgets.addAll(_buildChildren(child, depth + 1));
    }
    return widgets;
  }

  Widget _buildGroupTile(KdbxGroup group, int depth) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = group == _selected;
    final isRoot = group == widget.db.root;

    return InkWell(
      onTap: () => setState(() => _selected = group),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 40,
        padding: EdgeInsets.only(left: 8.0 + depth * 20, right: 8),
        child: Row(
          children: [
            Radio<KdbxGroup>(
              value: group,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            Icon(
              isRoot ? Icons.folder_open_rounded : Icons.folder_rounded,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRoot ? '根目录' : group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
