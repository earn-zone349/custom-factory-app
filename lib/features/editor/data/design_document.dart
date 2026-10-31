import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/design_element.dart';

/// A saved design: the product it is for and every element on the canvas.
/// Serialized to JSON (images as base64) so it can be stored locally now and
/// uploaded to the cloud later without changing the format.
@immutable
class DesignDocument {
  const DesignDocument({
    required this.category,
    required this.baseColorValue,
    required this.elements,
    this.version = currentVersion,
  });

  /// Parses a document. Throws [FormatException] for invalid data.
  factory DesignDocument.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Design file is not valid');
    }
    final int version = _readInt(decoded, 'version');
    if (version > currentVersion) {
      throw FormatException('Unsupported design version $version');
    }
    final Object? rawElements = decoded['elements'];
    if (rawElements is! List<dynamic>) {
      throw const FormatException('Design has no elements list');
    }
    return DesignDocument(
      version: version,
      category: _readString(decoded, 'category'),
      baseColorValue: _readInt(decoded, 'baseColor'),
      elements: rawElements.map((Object? item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid element entry');
        }
        return _elementFromMap(item);
      }).toList(),
    );
  }

  static const int currentVersion = 1;

  final int version;
  final String category;

  /// ARGB value of the product color.
  final int baseColorValue;
  final List<DesignElement> elements;

  Color get baseColor => Color(baseColorValue);

  String toJson() {
    return jsonEncode(<String, Object?>{
      'version': version,
      'category': category,
      'baseColor': baseColorValue,
      'elements': elements.map(_elementToMap).toList(),
    });
  }

  static Map<String, Object?> _elementToMap(DesignElement element) {
    final Map<String, Object?> base = <String, Object?>{
      'id': element.id,
      'x': element.x,
      'y': element.y,
      'scale': element.scale,
      'rotation': element.rotation,
      'opacity': element.opacity,
    };
    return switch (element) {
      TextElement t => <String, Object?>{
          ...base,
          'type': 'text',
          'text': t.text,
          'fontSize': t.fontSize,
          'color': t.color.toARGB32(),
          'fontFamily': t.fontFamily,
          'bold': t.bold,
          'italic': t.italic,
        },
      ShapeElement s => <String, Object?>{
          ...base,
          'type': 'shape',
          'kind': s.kind.name,
          'color': s.color.toARGB32(),
          'width': s.width,
          'height': s.height,
        },
      ImageElement i => <String, Object?>{
          ...base,
          'type': 'image',
          'data': base64Encode(i.bytes),
          'width': i.width,
          'height': i.height,
        },
    };
  }

  static DesignElement _elementFromMap(Map<String, dynamic> map) {
    final String id = _readString(map, 'id');
    final double x = _readDouble(map, 'x');
    final double y = _readDouble(map, 'y');
    final double scale = _readDouble(map, 'scale');
    final double rotation = _readDouble(map, 'rotation');
    final double opacity = _readDouble(map, 'opacity');

    switch (_readString(map, 'type')) {
      case 'text':
        return TextElement(
          id: id,
          x: x,
          y: y,
          scale: scale,
          rotation: rotation,
          opacity: opacity,
          text: _readString(map, 'text'),
          fontSize: _readDouble(map, 'fontSize'),
          color: Color(_readInt(map, 'color')),
          fontFamily: _readString(map, 'fontFamily'),
          bold: _readBool(map, 'bold'),
          italic: _readBool(map, 'italic'),
        );
      case 'shape':
        final String kindName = _readString(map, 'kind');
        final ShapeKind kind = ShapeKind.values.firstWhere(
          (ShapeKind k) => k.name == kindName,
          orElse: () => throw const FormatException('Unknown shape kind'),
        );
        return ShapeElement(
          id: id,
          x: x,
          y: y,
          scale: scale,
          rotation: rotation,
          opacity: opacity,
          kind: kind,
          color: Color(_readInt(map, 'color')),
          width: _readDouble(map, 'width'),
          height: _readDouble(map, 'height'),
        );
      case 'image':
        return ImageElement(
          id: id,
          x: x,
          y: y,
          scale: scale,
          rotation: rotation,
          opacity: opacity,
          bytes: base64Decode(_readString(map, 'data')),
          width: _readDouble(map, 'width'),
          height: _readDouble(map, 'height'),
        );
      default:
        throw const FormatException('Unknown element type');
    }
  }

  static double _readDouble(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is num) return value.toDouble();
    throw FormatException('Invalid or missing "$key"');
  }

  static int _readInt(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is num) return value.toInt();
    throw FormatException('Invalid or missing "$key"');
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is String) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static bool _readBool(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is bool) return value;
    throw FormatException('Invalid or missing "$key"');
  }
}
