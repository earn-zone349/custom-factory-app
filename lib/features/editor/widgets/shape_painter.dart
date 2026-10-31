import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/design_element.dart';

/// Paints the vector shapes available in the editor.
class ShapePainter extends CustomPainter {
  const ShapePainter({required this.kind, required this.color});

  final ShapeKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(_buildPath(size), paint);
  }

  Path _buildPath(Size size) {
    switch (kind) {
      case ShapeKind.rectangle:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Offset.zero & size,
              const Radius.circular(8),
            ),
          );
      case ShapeKind.circle:
        return Path()..addOval(Offset.zero & size);
      case ShapeKind.triangle:
        return Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
      case ShapeKind.star:
        return _starPath(size);
    }
  }

  Path _starPath(Size size) {
    final Offset center = size.center(Offset.zero);
    final double outer = math.min(size.width, size.height) / 2;
    final double inner = outer * 0.45;
    final Path path = Path();
    for (int i = 0; i < 10; i++) {
      final double radius = i.isEven ? outer : inner;
      final double angle = -math.pi / 2 + i * math.pi / 5;
      final Offset point = center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant ShapePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}
