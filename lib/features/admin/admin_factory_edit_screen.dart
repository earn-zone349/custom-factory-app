import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../catalog/catalog_scope.dart';
import '../catalog/models/catalog_entry.dart';
import '../checkout/widgets/district_picker.dart';
import '../manufacturers/manufacturer_controller.dart';
import '../manufacturers/manufacturer_scope.dart';
import '../manufacturers/models/manufacturer.dart';

/// Adds a new factory or edits an existing one.
class AdminFactoryEditScreen extends StatefulWidget {
  const AdminFactoryEditScreen({super.key, this.entry});

  /// The factory to edit, or null to add a new one.
  final Manufacturer? entry;

  @override
  State<AdminFactoryEditScreen> createState() => _AdminFactoryEditScreenState();
}

class _AdminFactoryEditScreenState extends State<AdminFactoryEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;

  String? _district;
  late List<String> _categories;
  late bool _isActive;
  String? _categoriesError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final Manufacturer? entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _contactController = TextEditingController(text: entry?.contactPerson ?? '');
    _phoneController = TextEditingController(text: entry?.phone ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');
    _district = entry?.district;
    _categories = List<String>.of(entry?.categories ?? const <String>[]);
    _isActive = entry?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Product names from the catalog, plus any already chosen name that is no
  /// longer in the catalog (so it is never lost silently).
  List<String> _availableCategories() {
    final List<CatalogEntry> catalog =
        CatalogScope.maybeOf(context)?.entries ?? const <CatalogEntry>[];
    final List<String> names = <String>[
      for (final CatalogEntry entry in catalog) entry.name,
    ];
    for (final String chosen in _categories) {
      if (!names.contains(chosen)) names.add(chosen);
    }
    return names;
  }

  void _toggleCategory(String name, bool selected) {
    setState(() {
      if (selected) {
        if (!_categories.contains(name)) _categories.add(name);
      } else {
        _categories.remove(name);
      }
      _categoriesError = null;
    });
  }

  String? _validateName(String? value) {
    final String name = (value ?? '').trim();
    if (name.length < ManufacturerRules.minNameLength) {
      return 'Enter at least ${ManufacturerRules.minNameLength} characters';
    }
    if (name.length > ManufacturerRules.maxNameLength) {
      return 'Use at most ${ManufacturerRules.maxNameLength} characters';
    }
    final ManufacturerController controller = ManufacturerScope.of(context);
    if (controller.isNameTaken(name, excludingId: widget.entry?.id)) {
      return 'Another factory already uses this name';
    }
    return null;
  }

  String? _validateContact(String? value) {
    final String contact = (value ?? '').trim();
    if (contact.length < ManufacturerRules.minNameLength) {
      return 'Enter the contact person';
    }
    return null;
  }

  Future<void> _pickDistrict(FormFieldState<String> field) async {
    final String? picked = await showDistrictPicker(
      context,
      selected: _district,
    );
    if (picked == null || !mounted) return;
    setState(() => _district = picked);
    field.didChange(picked);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final bool formOk = _formKey.currentState?.validate() ?? false;
    final bool hasCategories = _categories.isNotEmpty;
    setState(() {
      _categoriesError =
          hasCategories ? null : 'Select at least one product';
    });
    final String? district = _district;
    if (!formOk || !hasCategories || district == null) return;

    final ManufacturerController controller = ManufacturerScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final Manufacturer entry = Manufacturer(
      id: widget.entry?.id ?? ManufacturerController.newId(),
      name: _nameController.text.trim(),
      contactPerson: _contactController.text.trim(),
      phone: _phoneController.text.trim(),
      district: district,
      categories: List<String>.of(_categories),
      notes: _notesController.text.trim(),
      isActive: _isActive,
    );

    setState(() => _isSaving = true);
    try {
      await controller.save(entry);
      _showMessage(messenger, 'Factory saved');
      navigator.pop();
    } on ManufacturerException catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(messenger, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final Manufacturer? entry = widget.entry;
    if (entry == null || _isSaving) return;

    final ManufacturerController controller = ManufacturerScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this factory?'),
          content: const Text(
            'Orders already assigned to it keep its name. This cannot be undone.',
          ),
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
      await controller.delete(entry.id);
      _showMessage(messenger, 'Factory deleted');
      navigator.pop();
    } on ManufacturerException catch (error) {
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
    final Manufacturer? entry = widget.entry;
    final String? categoriesError = _categoriesError;

    return Scaffold(
      appBar: AppBar(
        title: Text(entry == null ? 'Add factory' : 'Edit factory'),
        actions: <Widget>[
          if (entry != null)
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
                  LengthLimitingTextInputFormatter(
                    ManufacturerRules.maxNameLength,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Factory name',
                  prefixIcon: Icon(Icons.factory_outlined),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _contactController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    ManufacturerRules.maxContactLength,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Contact person',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: _validateContact,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '01XXXXXXXXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              FormField<String>(
                validator: (String? _) {
                  return _district == null ? 'Select a district' : null;
                },
                builder: (FormFieldState<String> field) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => _pickDistrict(field),
                    child: InputDecorator(
                      isEmpty: _district == null,
                      decoration: InputDecoration(
                        labelText: 'District',
                        prefixIcon: const Icon(Icons.map_outlined),
                        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                        errorText: field.errorText,
                      ),
                      child: Text(_district ?? ''),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Products this factory can make',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: _availableCategories().map((String name) {
                  return FilterChip(
                    label: Text(name),
                    selected: _categories.contains(name),
                    selectedColor: AppColors.primaryLight,
                    onSelected: (bool selected) =>
                        _toggleCategory(name, selected),
                  );
                }).toList(),
              ),
              if (categoriesError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    categoriesError,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(
                    ManufacturerRules.maxNotesLength,
                  ),
                ],
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Minimum order, delivery time, address...',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('Inactive factories get no new orders'),
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
