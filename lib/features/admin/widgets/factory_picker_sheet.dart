import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../manufacturers/models/manufacturer.dart';

/// The admin's decision in the factory picker.
@immutable
class FactoryChoice {
  const FactoryChoice(this.manufacturer);

  /// The chosen factory, or null to remove the current assignment.
  final Manufacturer? manufacturer;
}

/// Shows the factories that can take an order. Returns the choice, or null
/// if the admin closed the sheet without choosing.
Future<FactoryChoice?> showFactoryPicker(
  BuildContext context, {
  required List<Manufacturer> factories,
  required Set<String> requiredCategories,
  String? selectedId,
  bool canRemove = false,
}) {
  return showModalBottomSheet<FactoryChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return _FactoryPickerSheet(
        factories: factories,
        requiredCategories: requiredCategories,
        selectedId: selectedId,
        canRemove: canRemove,
      );
    },
  );
}

class _FactoryPickerSheet extends StatelessWidget {
  const _FactoryPickerSheet({
    required this.factories,
    required this.requiredCategories,
    required this.selectedId,
    required this.canRemove,
  });

  final List<Manufacturer> factories;
  final Set<String> requiredCategories;
  final String? selectedId;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double height = MediaQuery.sizeOf(context).height * 0.7;

    // Factories that can make everything first, then by name.
    final List<Manufacturer> sorted = List<Manufacturer>.of(factories)
      ..sort((Manufacturer a, Manufacturer b) {
        final bool aOk = a.missingFor(requiredCategories).isEmpty;
        final bool bOk = b.missingFor(requiredCategories).isEmpty;
        if (aOk != bOk) return aOk ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final bool anyEligible = sorted.any(
      (Manufacturer m) => m.missingFor(requiredCategories).isEmpty,
    );

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose a factory',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Products in this order: ${requiredCategories.join(', ')}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (canRemove)
              ListTile(
                leading: const Icon(
                  Icons.link_off_rounded,
                  color: AppColors.error,
                ),
                title: const Text('Remove current factory'),
                onTap: () =>
                    Navigator.of(context).pop(const FactoryChoice(null)),
              ),
            Expanded(
              child: sorted.isEmpty
                  ? const _EmptyMessage(
                      message:
                          'No active factories yet. Add one from Admin panel, then Factories.',
                    )
                  : ListView(
                      children: <Widget>[
                        if (!anyEligible)
                          const Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: Text(
                              'No factory makes all the products in this order. Edit a factory and select these products.',
                            ),
                          ),
                        for (final Manufacturer factory in sorted)
                          _FactoryTile(
                            factory: factory,
                            missing: factory.missingFor(requiredCategories),
                            isSelected: factory.id == selectedId,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactoryTile extends StatelessWidget {
  const _FactoryTile({
    required this.factory,
    required this.missing,
    required this.isSelected,
  });

  final Manufacturer factory;
  final List<String> missing;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final bool eligible = missing.isEmpty;

    return ListTile(
      enabled: eligible,
      leading: CircleAvatar(
        backgroundColor:
            eligible ? AppColors.primaryLight : AppColors.border,
        child: Icon(
          Icons.factory_outlined,
          color: eligible ? AppColors.primary : AppColors.textMuted,
        ),
      ),
      title: Text(factory.name),
      subtitle: Text(
        eligible
            ? '${factory.district} · ${factory.contactPerson} · ${factory.phone}'
            : 'Does not make: ${missing.join(', ')}',
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: eligible
          ? () => Navigator.of(context).pop(FactoryChoice(factory))
          : null,
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
