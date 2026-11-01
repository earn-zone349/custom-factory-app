import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_scope.dart';
import '../catalog/models/catalog_entry.dart';
import 'admin_catalog_edit_screen.dart';

enum _CatalogMenuAction { reset }

/// All products with their prices. Admins can show, hide, edit and add.
class AdminCatalogScreen extends StatelessWidget {
  const AdminCatalogScreen({super.key});

  void _openEditor(BuildContext context, {CatalogEntry? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminCatalogEditScreen(entry: entry),
      ),
    );
  }

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(
    BuildContext context,
    CatalogController catalog,
    CatalogEntry entry,
    bool value,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await catalog.setActive(entry.id, isActive: value);
    } on CatalogException catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(messenger, 'Could not save the change. Please try again.');
    }
  }

  Future<void> _confirmReset(
    BuildContext context,
    CatalogController catalog,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reset to defaults?'),
          content: const Text(
            'All your changes to products, prices, styles and sizes will be removed. Products you added will be deleted.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await catalog.resetToDefaults();
      _showMessage(messenger, 'Products reset to the defaults');
    } on Exception {
      _showMessage(messenger, 'Could not reset. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final CatalogController catalog = CatalogScope.of(context);
    final List<CatalogEntry> entries = catalog.entries;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products and prices'),
        actions: <Widget>[
          PopupMenuButton<_CatalogMenuAction>(
            tooltip: 'More',
            onSelected: (_CatalogMenuAction action) =>
                _confirmReset(context, catalog),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<_CatalogMenuAction>>[
              PopupMenuItem<_CatalogMenuAction>(
                value: _CatalogMenuAction.reset,
                child: Text('Reset to defaults'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add product'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          96,
        ),
        children: <Widget>[
          Text(
            'Changes appear in the customer app right away. Prices apply to new orders only.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final CatalogEntry entry in entries)
            _CatalogTile(
              entry: entry,
              onTap: () => _openEditor(context, entry: entry),
              onToggle: (bool value) =>
                  _toggle(context, catalog, entry, value),
            ),
        ],
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.entry,
    required this.onTap,
    required this.onToggle,
  });

  final CatalogEntry entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String price = entry.startingPrice > 0
        ? 'From ${Formatters.price(entry.startingPrice)} per piece'
        : 'Quote after review';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: entry.isActive
                      ? AppColors.primaryLight
                      : AppColors.border,
                  child: Icon(
                    entry.icon,
                    color: entry.isActive
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        price,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${entry.styles.length} styles · ${entry.sizes.length} sizes',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      if (!entry.isActive)
                        Text(
                          'Hidden from customers',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(value: entry.isActive, onChanged: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
