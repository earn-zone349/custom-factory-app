import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import 'data/design_document.dart';
import 'data/design_exporter.dart';
import 'data/design_storage.dart';
import 'design_controller.dart';
import 'models/design_element.dart';
import 'models/design_template.dart';
import 'widgets/canvas_element_view.dart';
import 'widgets/editor_menu_button.dart';
import 'widgets/properties_panel.dart';
import 'widgets/template_picker.dart';
import 'widgets/text_input_dialog.dart';

/// Canva-style editor: add text and shapes, move, resize, rotate, style.
class DesignEditorScreen extends StatefulWidget {
  const DesignEditorScreen({
    super.key,
    required this.categoryName,
    required this.baseColor,
    this.initialElements = const <DesignElement>[],
    this.designId,
  });

  final String categoryName;

  /// Color of the product the customer is designing on.
  final Color baseColor;

  /// Elements to start with when reopening a saved design.
  final List<DesignElement> initialElements;

  /// Id of the saved design being edited (null for a new design).
  final String? designId;

  @override
  State<DesignEditorScreen> createState() => _DesignEditorScreenState();
}

class _DesignEditorScreenState extends State<DesignEditorScreen> {
  late final DesignController _controller;
  final ImagePicker _picker = ImagePicker();
  final DesignStorage _storage = DesignStorage();
  bool _isBusy = false;
  String? _designId;
  List<DesignElement> _savedElements = const <DesignElement>[];

  @override
  void initState() {
    super.initState();
    final bool isDark =
        ThemeData.estimateBrightnessForColor(widget.baseColor) ==
            Brightness.dark;
    _controller = DesignController(
      defaultTextColor: isDark ? Colors.white : Colors.black,
    );
    _controller.loadElements(widget.initialElements);
    _designId = widget.designId;
    _savedElements = _controller.elements;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addText() async {
    final String? text = await showTextInputDialog(context, title: 'Add text');
    if (text == null || !mounted) return;
    if (!_controller.addText(text)) {
      _showMessage('Could not add text.');
    }
  }

  Future<void> _addShape() async {
    final ShapeKind? shape = await showModalBottomSheet<ShapeKind>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: ShapeKind.values.map((ShapeKind item) {
                return ActionChip(
                  avatar: Icon(item.icon, size: 18),
                  label: Text(item.label),
                  onPressed: () => Navigator.of(sheetContext).pop(item),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (shape == null || !mounted) return;
    if (!_controller.addShape(shape)) {
      _showMessage('Canvas is full.');
    }
  }

  /// Picks a photo or logo from the gallery and adds it to the canvas.
  Future<void> _addImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final decoded = await decodeImageFromList(bytes);
      final double aspectRatio = decoded.width / decoded.height;
      decoded.dispose();
      if (!mounted) return;
      if (!_controller.addImage(bytes, aspectRatio)) {
        _showMessage('Could not add the image.');
      }
    } on Exception {
      if (!mounted) return;
      _showMessage('Could not load the image. Please try another one.');
    }
  }

  Future<void> _editText(TextElement element) async {
    final String? text = await showTextInputDialog(
      context,
      title: 'Edit text',
      initialText: element.text,
    );
    if (text == null || !mounted) return;
    _controller.updateElement(
      element.id,
      (DesignElement c) => c is TextElement ? c.copyWith(text: text) : c,
    );
  }

  /// Opens the template picker and applies the chosen template.
  Future<void> _openTemplates() async {
    final DesignTemplate? template = await showTemplatePicker(
      context,
      baseColor: widget.baseColor,
    );
    if (template == null || !mounted) return;

    if (_controller.elements.isNotEmpty) {
      final bool? replace = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Replace current design?'),
            content: const Text(
              'Your current design will be replaced. You can undo this.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Replace'),
              ),
            ],
          );
        },
      );
      if (replace != true || !mounted) return;
    }

    final TemplateTheme theme = TemplateTheme.forBase(widget.baseColor);
    if (!_controller.applyTemplate(template, theme)) {
      _showMessage('Could not apply the template.');
    }
  }

  /// True when the canvas differs from the last saved version.
  bool get _hasUnsavedChanges {
    if (_controller.elements.isEmpty && _designId == null) return false;
    return !_controller.matches(_savedElements);
  }

  /// Back button: asks what to do with unsaved changes.
  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final _LeaveChoice? choice = await showDialog<_LeaveChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Save your design?'),
          content: const Text('You have unsaved changes.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveChoice.discard),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_LeaveChoice.save),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice == _LeaveChoice.discard) {
      Navigator.of(context).pop();
      return;
    }
    await _finishAndClose();
  }

  /// Saves the design and closes the editor.
  Future<void> _finishAndClose() async {
    final bool saved = await _saveDesign(showConfirmation: false);
    if (!saved || !mounted) return;
    _showMessage('Design saved. Find it in the Design tab.');
    Navigator.of(context).pop(_designId);
  }

  /// Done button: saves the design and closes the editor.
  Future<void> _onDone() => _finishAndClose();

  /// Snapshot of the current design for saving.
  DesignDocument _snapshot() {
    return DesignDocument(
      category: widget.categoryName,
      baseColorValue: widget.baseColor.toARGB32(),
      elements: _controller.elements,
    );
  }

  void _onMenuAction(EditorMenuAction action) {
    switch (action) {
      case EditorMenuAction.save:
        _saveDesign();
      case EditorMenuAction.export:
        _exportPrintFile();
    }
  }

  /// Saves the design on this device. Returns true on success.
  Future<bool> _saveDesign({bool showConfirmation = true}) async {
    if (_isBusy) return false;
    if (_controller.elements.isEmpty) {
      _showMessage('Add something to your design first.');
      return false;
    }
    setState(() => _isBusy = true);
    try {
      final String id = await _storage.save(_snapshot(), id: _designId);
      _designId = id;
      _savedElements = _controller.elements;
      if (mounted && showConfirmation) {
        _showMessage('Design saved on this device.');
      }
      return true;
    } on Exception {
      if (mounted) {
        _showMessage('Could not save the design. Please try again.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Renders the print-ready PNG and opens the share sheet.
  Future<void> _exportPrintFile() async {
    if (_isBusy) return;
    final List<DesignElement> elements = _controller.elements;
    if (elements.isEmpty) {
      _showMessage('Add something to your design first.');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final List<int> png = await DesignExporter.renderPng(elements);
      final Directory directory = await getTemporaryDirectory();
      final File file = File(
        '${directory.path}/print_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'image/png')],
        subject: 'Print file - ${widget.categoryName}',
      );
    } on Exception {
      if (!mounted) return;
      _showMessage('Could not create the print file. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _handleBack();
      },
      child: ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        final DesignElement? selected = _controller.selected;

        return Scaffold(
          appBar: AppBar(
            title: Text('Design your ${widget.categoryName}'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Undo',
                onPressed: _controller.canUndo ? _controller.undo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: _controller.canRedo ? _controller.redo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
              EditorMenuButton(
                enabled: !_isBusy,
                onSelected: _onMenuAction,
              ),
              IconButton(
                tooltip: 'Done',
                onPressed: _onDone,
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              if (_isBusy) const LinearProgressIndicator(),
              Expanded(
                child: _CanvasArea(
                  controller: _controller,
                  baseColor: widget.baseColor,
                ),
              ),
              if (selected != null)
                PropertiesPanel(
                  controller: _controller,
                  element: selected,
                  onEditText: () {
                    if (selected is TextElement) _editText(selected);
                  },
                ),
              _AddToolbar(
                onAddText: _addText,
                onAddShape: _addShape,
                onAddImage: _addImage,
                onOpenTemplates: _openTemplates,
              ),
            ],
          ),
        );
      },
      ),
    );
  }
}

/// The product-colored canvas that holds all elements.
class _CanvasArea extends StatelessWidget {
  const _CanvasArea({required this.controller, required this.baseColor});

  final DesignController controller;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double padding = AppSpacing.md;
        final double availableWidth = constraints.maxWidth - padding * 2;
        final double availableHeight = constraints.maxHeight - padding * 2;
        if (availableWidth <= 0 || availableHeight <= 0) {
          return const SizedBox.shrink();
        }

        final double unit = math.min(
          availableWidth / CanvasSpec.width,
          availableHeight / CanvasSpec.height,
        );
        final bool isDark =
            ThemeData.estimateBrightnessForColor(baseColor) == Brightness.dark;
        final List<DesignElement> elements = controller.elements;

        return Center(
          child: Container(
            width: CanvasSpec.width * unit,
            height: CanvasSpec.height * unit,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.select(null),
                    ),
                  ),
                  if (elements.isEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            'Tap Text or Shape below\nto start designing',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final DesignElement element in elements)
                    CanvasElementView(
                      key: ValueKey<String>(element.id),
                      element: element,
                      controller: controller,
                      unit: unit,
                      isSelected: element.id == controller.selectedId,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom toolbar with the "add" tools.
class _AddToolbar extends StatelessWidget {
  const _AddToolbar({
    required this.onAddText,
    required this.onAddShape,
    required this.onAddImage,
    required this.onOpenTemplates,
  });

  final VoidCallback onAddText;
  final VoidCallback onAddShape;
  final VoidCallback onAddImage;
  final VoidCallback onOpenTemplates;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _ToolButton(
                  icon: Icons.title_rounded,
                  label: 'Text',
                  onTap: onAddText,
                ),
              ),
              Expanded(
                child: _ToolButton(
                  icon: Icons.category_rounded,
                  label: 'Shape',
                  onTap: onAddShape,
                ),
              ),
              Expanded(
                child: _ToolButton(
                  icon: Icons.image_rounded,
                  label: 'Image',
                  onTap: onAddImage,
                ),
              ),
              Expanded(
                child: _ToolButton(
                  icon: Icons.dashboard_customize_rounded,
                  label: 'Templates',
                  onTap: onOpenTemplates,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// What to do with unsaved changes when leaving the editor.
enum _LeaveChoice { save, discard }
