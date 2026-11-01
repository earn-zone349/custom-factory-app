import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../editor/design_editor_screen.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_scope.dart';
import '../cart/cart_screen.dart';
import '../cart/models/cart_item.dart';
import '../editor/data/design_document.dart';
import '../editor/data/design_storage.dart';
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

  /// Opens the design editor. When the customer finishes, the product and
  /// the saved design are added to the cart.
  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final CartController cart = CartScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CategoryConfig config = widget.config;
    final ColorOption chosenColor = CategoryConfig.colors[_colorIndex];
    final String? style = _style;
    final String? size = _size;
    final int quantity = _quantity;
    final String notes = _notesController.text.trim();

    final String? designId = await navigator.push<String>(
      MaterialPageRoute<String>(
        builder: (_) => DesignEditorScreen(
          categoryName: config.name,
          baseColor: chosenColor.value,
        ),
      ),
    );
    if (designId == null || !mounted) return;

    // The customer may have changed the product color inside the editor.
    ColorOption color = chosenColor;
    try {
      final DesignDocument document = await DesignStorage().load(designId);
      color = _colorFor(document.baseColor) ??
          ColorOption(name: 'Custom', value: document.baseColor);
    } on Exception catch (error) {
      debugPrint('Could not read the saved design color: $error');
    }

    final CartItem item = CartItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: config.name,
      style: style,
      size: size,
      colorName: color.name,
      colorValue: color.value.toARGB32(),
      quantity: quantity,
      unitPrice: config.startingPrice,
      notes: notes,
      designId: designId,
    );

    try {
      final bool added = await cart.add(item);
      if (!added) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Your cart is full. Remove an item first.'),
            ),
          );
        return;
      }
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not add to cart. Please try again.'),
          ),
        );
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to cart'),
          action: SnackBarAction(
            label: 'View cart',
            onPressed: () {
              navigator.push(
                MaterialPageRoute<void>(builder: (_) => const CartScreen()),
              );
            },
          ),
        ),
      );
    if (mounted) navigator.pop();
  }

  /// Finds the palette color with this value, or null for a custom color.
  static ColorOption? _colorFor(Color value) {
    for (final ColorOption option in CategoryConfig.colors) {
      if (option.value == value) return option;
    }
    return null;
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
