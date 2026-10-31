import 'dart:typed_data' as typed;

import 'package:flutter/material.dart';

/// Fixed logical canvas size. Every element uses these units, so a design
/// looks identical on all screens and exports consistently later.
class CanvasSpec {
  const CanvasSpec._();

  static const double width = 360;
  static const double height = 420;
}

/// Available shape types.
enum ShapeKind {
  rectangle('Rectangle', Icons.crop_square_rounded),
  circle('Circle', Icons.circle_outlined),
  triangle('Triangle', Icons.change_history_rounded),
  star('Star', Icons.star_outline_rounded);

  const ShapeKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Base class of everything placed on the canvas. Immutable: every change
/// creates a new object, which makes undo/redo simple and safe.
@immutable
sealed class DesignElement {
  const DesignElement({
    required this.id,
    required this.x,
    required this.y,
    this.scale = 1,
    this.rotation = 0,
    this.opacity = 1,
  });

  final String id;

  /// Center position in canvas units.
  final double x;
  final double y;
  final double scale;

  /// Rotation in radians.
  final double rotation;
  final double opacity;

  DesignElement transformed({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
  });

  DesignElement duplicated({required String newId});
}

/// A text layer.
final class TextElement extends DesignElement {
  const TextElement({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.opacity,
    required this.text,
    this.fontSize = 32,
    this.color = Colors.black,
    this.fontFamily = 'Poppins',
    this.bold = false,
    this.italic = false,
  });

  final String text;
  final double fontSize;
  final Color color;
  final String fontFamily;
  final bool bold;
  final bool italic;

  TextElement copyWith({
    String? id,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
    String? text,
    double? fontSize,
    Color? color,
    String? fontFamily,
    bool? bold,
    bool? italic,
  }) {
    return TextElement(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
    );
  }

  @override
  TextElement transformed({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
  }) {
    return copyWith(
      x: x,
      y: y,
      scale: scale,
      rotation: rotation,
      opacity: opacity,
    );
  }

  @override
  TextElement duplicated({required String newId}) {
    return copyWith(
      id: newId,
      x: (x + 16).clamp(0.0, CanvasSpec.width).toDouble(),
      y: (y + 16).clamp(0.0, CanvasSpec.height).toDouble(),
    );
  }
}

/// A vector shape layer.
final class ShapeElement extends DesignElement {
  const ShapeElement({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.opacity,
    required this.kind,
    this.color = const Color(0xFF16A34A),
    this.width = 120,
    this.height = 120,
  });

  final ShapeKind kind;
  final Color color;
  final double width;
  final double height;

  ShapeElement copyWith({
    String? id,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
    ShapeKind? kind,
    Color? color,
    double? width,
    double? height,
  }) {
    return ShapeElement(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      kind: kind ?? this.kind,
      color: color ?? this.color,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  ShapeElement transformed({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
  }) {
    return copyWith(
      x: x,
      y: y,
      scale: scale,
      rotation: rotation,
      opacity: opacity,
    );
  }

  @override
  ShapeElement duplicated({required String newId}) {
    return copyWith(
      id: newId,
      x: (x + 16).clamp(0.0, CanvasSpec.width).toDouble(),
      y: (y + 16).clamp(0.0, CanvasSpec.height).toDouble(),
    );
  }
}

/// A photo or logo picked from the gallery.
final class ImageElement extends DesignElement {
  const ImageElement({
    required super.id,
    required super.x,
    required super.y,
    super.scale,
    super.rotation,
    super.opacity,
    required this.bytes,
    required this.width,
    required this.height,
  });

  final typed.Uint8List bytes;
  final double width;
  final double height;

  ImageElement copyWith({
    String? id,
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
  }) {
    return ImageElement(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      bytes: bytes,
      width: width,
      height: height,
    );
  }

  @override
  ImageElement transformed({
    double? x,
    double? y,
    double? scale,
    double? rotation,
    double? opacity,
  }) {
    return copyWith(
      x: x,
      y: y,
      scale: scale,
      rotation: rotation,
      opacity: opacity,
    );
  }

  @override
  ImageElement duplicated({required String newId}) {
    return copyWith(
      id: newId,
      x: (x + 16).clamp(0.0, CanvasSpec.width).toDouble(),
      y: (y + 16).clamp(0.0, CanvasSpec.height).toDouble(),
    );
  }
}
