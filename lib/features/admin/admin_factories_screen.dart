import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../manufacturers/manufacturer_controller.dart';
import '../manufacturers/manufacturer_scope.dart';
import '../manufacturers/models/manufacturer.dart';
import 'admin_factory_edit_screen.dart';

/// All factories. Admins can add, edit, and switch them on or off.
class AdminFactoriesScreen extends StatelessWidget {
  const AdminFactoriesScreen({super.key});

  void _openEditor(BuildContext context, {Manufacturer? entry}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminFactoryEditScreen(entry: entry),
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
    ManufacturerController controller,
    Manufacturer entry,
    bool value,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await controller.setActive(entry.id, isActive: value);
    } on ManufacturerException catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(messenger, 'Could not save the change. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ManufacturerController controller = ManufacturerScope.of(context);
    final List<Manufacturer> entries = controller.entries;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget body;
    if (!controller.isLoaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (entries.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryLight,
                child: Icon(
                  Icons.factory_outlined,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No factories yet',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Add the factories that make your products, then assign orders to them.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          96,
        ),
        children: <Widget>[
          for (final Manufacturer entry in entries)
            _FactoryCard(
              entry: entry,
              onTap: () => _openEditor(context, entry: entry),
              onToggle: (bool value) =>
                  _toggle(context, controller, entry, value),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Factories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add factory'),
      ),
      body: body,
    );
  }
}

class _FactoryCard extends StatelessWidget {
  const _FactoryCard({
    required this.entry,
    required this.onTap,
    required this.onToggle,
  });

  final Manufacturer entry;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  backgroundColor: entry.isActive
                      ? AppColors.primaryLight
                      : AppColors.border,
                  child: Icon(
                    Icons.factory_outlined,
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
                        '${entry.district} · ${entry.contactPerson}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        entry.phone,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Makes: ${entry.categories.join(', ')}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                      if (!entry.isActive)
                        Text(
                          'Inactive: no new orders',
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
