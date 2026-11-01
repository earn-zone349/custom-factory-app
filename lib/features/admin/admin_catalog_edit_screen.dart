import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../catalog/catalog_controller.dart';
import '../catalog/catalog_scope.dart';
import '../catalog/models/catalog_entry.dart';
import '../catalog/models/catalog_icons.dart';
import 'widgets/chip_list_editor.dart';

/// Adds a new product or edits an existing one.
class AdminCatalogEditScreen extends StatefulWidget {
  const AdminCatalogEditScreen({super.key, this.entry});

  /// The product to edit, or null to add a new one.
  final CatalogEntry? entry;

  @override
  State<AdminCatalogEditScreen> createState() =>
      _AdminCatalogEditScreenState();
}

class _AdminCatalogEditScreenState extends State<AdminCatalogEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _priceController;

  late String _iconKey;
  late List<String> _styles;
  late List<String> _sizes;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final CatalogEntry? entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _subtitleController = TextEditingController(text: entry?.subtitle ?? '');
    _priceController = TextEditingController(
      text: entry == null ? '' : entry.startingPrice.round().toString(),
    );
    _iconKey = entry?.iconKey ?? CatalogIcons.fallbackKey;
    _styles = List<String>.of(entry?.styles ?? const <String>[]);
    _sizes = List<String>.of(entry?.sizes ?? const <String>[]);
    _isActive = entry?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateName(String? value) {
    final String name = (value ?? '').trim();
    if (name.length < CatalogRules.minNameLength) {
      return 'Enter at least ${CatalogRules.minNameLength} characters';
    }
    if (name.length > CatalogRules.maxNameLength) {
      return 'Use at most ${CatalogRules.maxNameLength} characters';
    }
    final CatalogController catalog = CatalogScope.of(context);
    if (catalog.isNameTaken(name, excludingId: widget.entry?.id)) {
      return 'Another product already uses this name';
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final int? parsed = int.tryParse((value ?? '').trim());
    if (parsed == null) return 'Enter a price (0 to quote after review)';
    if (parsed < 0 || parsed > CatalogRules.maxPrice) {
      return 'Enter a price up to ${CatalogRules.maxPrice}';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final CatalogController catalog = CatalogScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final CatalogEntry? existing = widget.entry;

    final CatalogEntry entry = CatalogEntry(
      id: existing?.id ?? CatalogController.newId(),
      name: _nameController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      iconKey: _iconKey,
      styles: _styles,
      sizes: _sizes,
      startingPrice: int.parse(_priceController.text.trim()).toDouble(),
      isActive: _isActive,
      isBuiltIn: existing?.isBuiltIn ?? false,
    );

    setState(() => _isSaving = true);
    try {
      await catalog.save(entry);
      _showMessage(messenger, 'Product saved');
      navigator.pop();
    } on CatalogException catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(messenger, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final CatalogEntry? entry = widget.entry;
    if (entry == null || _isSaving) return;

    final CatalogController catalog = CatalogScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this product?'),
          content: const Text('This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await catalog.delete(entry.id);
      _showMessage(messenger, 'Product deleted');
      navigator.pop();
    } on CatalogException catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(messenger, 'Could not delete. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final CatalogEntry? entry = widget.entry;
    final bool canDelete = entry != null && !entry.isBuiltIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry == null ? 'Add product' : 'Edit product'),
        actions: <Widget>[
          if (canDelete)
            IconButton(
              tooltip: 'Delete',
              onPressed: _isSaving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(CatalogRules.maxNameLength),
                ],
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _subtitleController,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    CatalogRules.maxSubtitleLength,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Short description (optional)',
                  prefixIcon: Icon(Icons.short_text_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(7),
                ],
                decoration: const InputDecoration(
                  labelText: 'Starting price per piece (BDT)',
                  helperText: 'Enter 0 to quote the price after review',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Icon',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: CatalogIcons.options.map((CatalogIconOption option) {
                  final bool selected = option.key == _iconKey;
                  return GestureDetector(
                    onTap: () => setState(() => _iconKey = option.key),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryLight
                            : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        option.icon,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
              ChipListEditor(
                title: 'Styles',
                hint: 'Add a style, for example Round Neck',
                helper:
                    'Leave empty to let customers describe the product themselves.',
                values: _styles,
                onChanged: (List<String> values) {
                  setState(() => _styles = values);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              ChipListEditor(
                title: 'Sizes',
                hint: 'Add a size, for example XL',
                helper: 'Leave empty if the product has no sizes.',
                values: _sizes,
                onChanged: (List<String> values) {
                  setState(() => _sizes = values);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible to customers'),
                subtitle: const Text('Hidden products are not shown in the app'),
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
        ),
      ),
    );
  }
}
