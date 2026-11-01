import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../customize/models/category_config.dart';

/// Bottom sheet listing every product color. Each tap is reported at once,
/// so the canvas behind the sheet updates live.
class ProductColorSheet extends StatefulWidget {
  const ProductColorSheet({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  State<ProductColorSheet> createState() => _ProductColorSheetState();
}

class _ProductColorSheetState extends State<ProductColorSheet> {
  late Color _selected = widget.selected;

  String get _selectedName {
    for (final ColorOption option in CategoryConfig.colors) {
      if (option.value == _selected) return option.name;
    }
    return 'Custom';
  }

  void _select(Color color) {
    setState(() => _selected = color);
    widget.onSelected(color);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Product color: $_selectedName',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: CategoryConfig.colors.map((ColorOption option) {
                return _Swatch(
                  option: option,
                  isSelected: option.value == _selected,
                  onTap: () => _select(option.value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final ColorOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool darkSwatch =
        ThemeData.estimateBrightnessForColor(option.value) == Brightness.dark;

    return Tooltip(
      message: option.name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: option.value,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isSelected
              ? Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: darkSwatch ? Colors.white : Colors.black,
                )
              : null,
        ),
      ),
    );
  }
}
