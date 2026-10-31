import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import 'models/category_config.dart';

/// Lets the customer choose style, color, size and quantity for any product
/// in a category, and describe their own idea.
class CustomizeProductScreen extends StatefulWidget {
  const CustomizeProductScreen({super.key, required this.config});

  final CategoryConfig config;

  @override
  State<CustomizeProductScreen> createState() => _CustomizeProductScreenState();
}

class _CustomizeProductScreenState extends State<CustomizeProductScreen> {
  static const int _maxQuantity = 1000000;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();

  String? _style;
  String? _size;
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    final CategoryConfig config = widget.config;
    _style = config.styles.isNotEmpty ? config.styles.first : null;
    _size = config.sizes.isNotEmpty ? config.sizes.first : null;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _quantity => int.tryParse(_quantityController.text.trim()) ?? 0;

  String? _validateQuantity(String? value) {
    final int? parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 1) return 'Enter a quantity of 1 or more';
    if (parsed > _maxQuantity) return 'Quantity is too large';
    return null;
  }

  String? _validateNotes(String? value) {
    if (widget.config.isCustom && (value == null || value.trim().isEmpty)) {
      return 'Please describe the product you want';
    }
    return null;
  }

  /// Placeholder until the design editor is built (next phase).
  void _onContinue() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Design editor is coming soon')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final CategoryConfig config = widget.config;
    final bool hasEstimate = config.startingPrice > 0 && _quantity > 0;

    return Scaffold(
      appBar: AppBar(title: Text(config.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Customize your ${config.name}',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose any style you like. Our factories will make it.',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              if (config.styles.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Style'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: config.styles.map((String style) {
                    return ChoiceChip(
                      label: Text(style),
                      selected: style == _style,
                      selectedColor: AppColors.primaryLight,
                      onSelected: (_) => setState(() => _style = style),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(
                'Color: ${CategoryConfig.colors[_colorIndex].name}',
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: List<Widget>.generate(
                  CategoryConfig.colors.length,
                  (int i) {
                    final bool selected = i == _colorIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _colorIndex = i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: CategoryConfig.colors[i].value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                selected ? AppColors.primary : AppColors.border,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (config.sizes.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('Size'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: config.sizes.map((String size) {
                    return ChoiceChip(
                      label: Text(size),
                      selected: size == _size,
                      selectedColor: AppColors.primaryLight,
                      onSelected: (_) => setState(() => _size = size),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const _SectionTitle('Quantity'),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: _validateQuantity,
                decoration: const InputDecoration(
                  labelText: 'How many pieces?',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(
                config.isCustom ? 'Describe your product' : 'Your idea (optional)',
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                validator: _validateNotes,
                decoration: InputDecoration(
                  hintText: config.isCustom
                      ? 'Tell us what you want to make'
                      : 'Any special requirement, material, or design idea',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: <Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    hasEstimate ? 'Estimated from' : 'Price',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    hasEstimate
                        ? Formatters.price(config.startingPrice * _quantity)
                        : 'Quote after review',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: ElevatedButton(
                  onPressed: _onContinue,
                  child: const Text('Continue to design'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small bold heading used above each selector.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
