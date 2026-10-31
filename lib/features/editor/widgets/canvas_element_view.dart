import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../design_controller.dart';
import '../models/design_element.dart';
import 'editor_text_style.dart';
import 'shape_painter.dart';

/// Draws one element on the canvas and handles move / pinch / rotate.
class CanvasElementView extends StatefulWidget {
  const CanvasElementView({
    super.key,
    required this.element,
    required this.controller,
    required this.unit,
    required this.isSelected,
  });

  final DesignElement element;
  final DesignController controller;

  /// Pixels per canvas unit.
  final double unit;
  final bool isSelected;

  @override
  State<CanvasElementView> createState() => _CanvasElementViewState();
}

class _CanvasElementViewState extends State<CanvasElementView> {
  static const double _minScale = 0.2;
  static const double _maxScale = 6;

  double _startScale = 1;
  double _startRotation = 0;

  void _onScaleStart(ScaleStartDetails details) {
    final DesignElement e = widget.element;
    _startScale = e.scale;
    _startRotation = e.rotation;
    widget.controller
      ..select(e.id)
      ..beginTransform();
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final double unit = widget.unit;
    widget.controller.transformLive(
      widget.element.id,
      dx: details.focalPointDelta.dx / unit,
      dy: details.focalPointDelta.dy / unit,
      scale: (_startScale * details.scale)
          .clamp(_minScale, _maxScale)
          .toDouble(),
      rotation: _startRotation + details.rotation,
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    widget.controller.endTransform();
  }

  Widget _buildContent(DesignElement element) {
    return switch (element) {
      ImageElement i => SizedBox(
          width: i.width,
          height: i.height,
          child: Image.memory(
            i.bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      TextElement t => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CanvasSpec.width - 40),
          child: Text(
            t.text,
            textAlign: TextAlign.center,
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
    };
  }

  @override
  Widget build(BuildContext context) {
    final DesignElement e = widget.element;
    final double unit = widget.unit;
    final double totalScale = e.scale * unit;

    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: Offset(
            (e.x - CanvasSpec.width / 2) * unit,
            (e.y - CanvasSpec.height / 2) * unit,
          ),
          child: Transform.rotate(
            angle: e.rotation,
            child: Transform.scale(
              scale: totalScale,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.controller.select(e.id),
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: widget.isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5 / totalScale,
                          ),
                        )
                      : null,
                  child: Opacity(
                    opacity: e.opacity,
                    child: _buildContent(e),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
