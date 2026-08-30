part of 'settings_screen.dart';

/// One entry in the desktop settings sidebar.
class _SettingsCategorySpec {
  final IconData icon;
  final String label;
  final Widget content;

  const _SettingsCategorySpec({
    required this.icon,
    required this.label,
    required this.content,
  });
}

/// Desktop settings layout: a category sidebar on the left and an
/// [IndexedStack] of detail panes on the right so every pane keeps its state
/// (e.g. unsaved WebDAV form edits) while the user switches categories.
class _SettingsWideLayout extends StatefulWidget {
  final List<_SettingsCategorySpec> categories;

  const _SettingsWideLayout({required this.categories});

  @override
  State<_SettingsWideLayout> createState() => _SettingsWideLayoutState();
}

class _SettingsWideLayoutState extends State<_SettingsWideLayout> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 220,
          decoration: BoxDecoration(
            boxShadow: ClayDecoration.sidebarShadow(brightness),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              vertical: ClayLayout.space16,
              horizontal: ClayLayout.space8,
            ),
            children: [
              for (var i = 0; i < widget.categories.length; i++)
                _SettingsNavItem(
                  icon: widget.categories[i].icon,
                  label: widget.categories[i].label,
                  selected: i == _selectedIndex,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              for (final category in widget.categories) category.content,
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(ClayLayout.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(ClayLayout.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ClayLayout.space12,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: ClayLayout.space12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
