import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../design_controller.dart';
import '../models/design_element.dart';
import 'editor_text_style.dart';

/// Bottom panel with options for the selected element.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({
    super.key,
    required this.controller,
    required this.element,
    required this.onEditText,
  });

  final DesignController controller;
  final DesignElement element;
  final VoidCallback onEditText;

  static const List<Color> _palette = <Color>[
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFF16A34A),
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFFFACC15),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF7C3AED),
    Color(0xFF6B7280),
    Color(0xFF1E3A8A),
    Color(0xFF92400E),
  ];

  @override
  Widget build(BuildContext context) {
    final DesignElement current = element;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildActions(),
              if (current is! ImageElement) ...<Widget>[
                const _Label('Color'),
                _buildColors(),
              ],
              if (current is TextElement) ..._buildTextControls(current),
              if (current is ShapeElement) ..._buildShapeControls(current),
              const _Label('Opacity'),
              _buildOpacity(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          if (element is TextElement)
            _ActionButton(
              icon: Icons.edit_rounded,
              label: 'Edit',
              onTap: onEditText,
            ),
          _ActionButton(
            icon: Icons.copy_rounded,
            label: 'Duplicate',
            onTap: controller.duplicateSelected,
          ),
          _ActionButton(
            icon: Icons.flip_to_front_rounded,
            label: 'Forward',
            onTap: controller.moveForward,
          ),
          _ActionButton(
            icon: Icons.flip_to_back_rounded,
            label: 'Backward',
            onTap: controller.moveBackward,
          ),
          _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            onTap: controller.deleteSelected,
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Widget _buildColors() {
    final Color selectedColor = switch (element) {
      TextElement t => t.color,
      ShapeElement s => s.color,
      ImageElement _ => Colors.transparent,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: _palette.map((Color swatch) {
          final bool isSelected = swatch == selectedColor;
          return GestureDetector(
            onTap: () {
              controller.updateElement(
                element.id,
                (DesignElement c) => switch (c) {
                  TextElement t => t.copyWith(color: swatch),
                  ShapeElement s => s.copyWith(color: swatch),
                  ImageElement i => i,
                },
              );
            },
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 3 : 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildTextControls(TextElement text) {
    return <Widget>[
      const _Label('Font'),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: EditorFonts.families.map((String family) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(family),
                selected: text.fontFamily == family,
                selectedColor: AppColors.primaryLight,
                onSelected: (_) {
                  controller.updateElement(
                    text.id,
                    (DesignElement c) =>
                        c is TextElement ? c.copyWith(fontFamily: family) : c,
                  );
                },
              ),
            );
          }).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            FilterChip(
              label: const Text('Bold'),
              selected: text.bold,
              selectedColor: AppColors.primaryLight,
              onSelected: (bool value) {
                controller.updateElement(
                  text.id,
                  (DesignElement c) =>
                      c is TextElement ? c.copyWith(bold: value) : c,
                );
              },
            ),
            const SizedBox(width: AppSpacing.sm),
            FilterChip(
              label: const Text('Italic'),
              selected: text.italic,
              selectedColor: AppColors.primaryLight,
              onSelected: (bool value) {
                controller.updateElement(
                  text.id,
                  (DesignElement c) =>
                      c is TextElement ? c.copyWith(italic: value) : c,
                );
              },
            ),
          ],
        ),
      ),
      const _Label('Size'),
      Slider(
        value: text.fontSize.clamp(12.0, 120.0).toDouble(),
        min: 12,
        max: 120,
        onChangeStart: (_) => controller.beginTransform(),
        onChanged: (double value) {
          controller.updateElement(
            text.id,
            (DesignElement c) =>
                c is TextElement ? c.copyWith(fontSize: value) : c,
            recordHistory: false,
          );
        },
        onChangeEnd: (_) => controller.endTransform(),
      ),
    ];
  }

  List<Widget> _buildShapeControls(ShapeElement shape) {
    return <Widget>[
      const _Label('Shape'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.sm,
          children: ShapeKind.values.map((ShapeKind kind) {
            return ChoiceChip(
              avatar: Icon(kind.icon, size: 18),
              label: Text(kind.label),
              selected: shape.kind == kind,
              selectedColor: AppColors.primaryLight,
              onSelected: (_) {
                controller.updateElement(
                  shape.id,
                  (DesignElement c) =>
                      c is ShapeElement ? c.copyWith(kind: kind) : c,
                );
              },
            );
          }).toList(),
        ),
      ),
    ];
  }

  Widget _buildOpacity() {
    return Slider(
      value: element.opacity.clamp(0.1, 1.0).toDouble(),
      min: 0.1,
      max: 1,
      onChangeStart: (_) => controller.beginTransform(),
      onChanged: (double value) {
        controller.updateElement(
          element.id,
          (DesignElement c) => c.transformed(opacity: value),
          recordHistory: false,
        );
      },
      onChangeEnd: (_) => controller.endTransform(),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textMuted,
            ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label, style: TextStyle(color: color)),
    );
  }
}
