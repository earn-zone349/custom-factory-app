import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/design_element.dart';
import 'editor_text_style.dart';
import 'shape_painter.dart';

/// Non-interactive miniature of a design on its product color.
class DesignPreview extends StatelessWidget {
  const DesignPreview({
    super.key,
    required this.elements,
    required this.baseColor,
  });

  final List<DesignElement> elements;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AspectRatio(
        aspectRatio: CanvasSpec.width / CanvasSpec.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: CanvasSpec.width,
                height: CanvasSpec.height,
                child: Stack(
                  children: <Widget>[
                    for (final DesignElement element in elements)
                      _PreviewElement(element: element),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewElement extends StatelessWidget {
  const _PreviewElement({required this.element});

  final DesignElement element;

  Widget _content() {
    return switch (element) {
      TextElement t => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CanvasSpec.width - 40),
          child: Text(
            t.text,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: EditorTextStyle.resolve(t),
          ),
        ),
      ShapeElement s => SizedBox(
          width: s.width,
          height: s.height,
          child: CustomPaint(
            painter: ShapePainter(kind: s.kind, color: s.color),
          ),
        ),
      ImageElement i => SizedBox(
          width: i.width,
          height: i.height,
          child: Image.memory(i.bytes, fit: BoxFit.contain),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(
            element.x - CanvasSpec.width / 2,
            element.y - CanvasSpec.height / 2,
          ),
          child: Transform.rotate(
            angle: element.rotation,
            child: Transform.scale(
              scale: element.scale,
              child: Opacity(opacity: element.opacity, child: _content()),
            ),
          ),
        ),
      ),
    );
  }
}
