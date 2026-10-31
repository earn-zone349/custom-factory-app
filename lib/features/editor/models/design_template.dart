import 'package:flutter/material.dart';

import 'design_element.dart';

/// Returns a fresh unique id for each new element.
typedef ElementIdGenerator = String Function();

/// Colors a template uses, chosen to stay readable on the product color.
@immutable
class TemplateTheme {
  const TemplateTheme({
    required this.ink,
    required this.accent,
    required this.onAccent,
  });

  /// Builds a theme with good contrast against [base].
  factory TemplateTheme.forBase(Color base) {
    final bool darkBase =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark;
    final Color ink = darkBase ? Colors.white : _dark;

    Color accent = _defaultAccent;
    if ((base.computeLuminance() - accent.computeLuminance()).abs() < 0.25) {
      accent = darkBase ? _highlight : _dark;
    }

    final bool darkAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark;
    return TemplateTheme(
      ink: ink,
      accent: accent,
      onAccent: darkAccent ? Colors.white : _dark,
    );
  }

  static const Color _dark = Color(0xFF111827);
  static const Color _defaultAccent = Color(0xFF16A34A);
  static const Color _highlight = Color(0xFFFACC15);

  /// Main text color.
  final Color ink;

  /// Highlight color for shapes and key words.
  final Color accent;

  /// Text color that reads well on top of [accent].
  final Color onAccent;
}

/// A ready-made layout the customer can start from.
@immutable
class DesignTemplate {
  const DesignTemplate({
    required this.name,
    required this.description,
    required this.build,
  });

  final String name;
  final String description;

  /// Creates the template's elements, taking ids from the generator.
  final List<DesignElement> Function(
    TemplateTheme theme,
    ElementIdGenerator nextId,
  ) build;
}

TextElement _text(
  ElementIdGenerator nextId,
  String text, {
  double x = CanvasSpec.width / 2,
  required double y,
  required double size,
  required Color color,
  String font = 'Poppins',
  bool bold = false,
  bool italic = false,
  double opacity = 1,
}) {
  return TextElement(
    id: nextId(),
    x: x,
    y: y,
    text: text,
    fontSize: size,
    color: color,
    fontFamily: font,
    bold: bold,
    italic: italic,
    opacity: opacity,
  );
}

ShapeElement _shape(
  ElementIdGenerator nextId,
  ShapeKind kind, {
  double x = CanvasSpec.width / 2,
  required double y,
  required Color color,
  required double width,
  required double height,
}) {
  return ShapeElement(
    id: nextId(),
    x: x,
    y: y,
    kind: kind,
    color: color,
    width: width,
    height: height,
  );
}

/// The built-in template catalogue.
class DesignTemplates {
  const DesignTemplates._();

  static final List<DesignTemplate> all = <DesignTemplate>[
    DesignTemplate(
      name: 'Bold Statement',
      description: 'Big headline',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _text(
          nextId,
          'YOUR\nMESSAGE',
          y: 190,
          size: 72,
          color: theme.ink,
          font: 'Bebas Neue',
        ),
        _shape(
          nextId,
          ShapeKind.rectangle,
          y: 300,
          color: theme.accent,
          width: 160,
          height: 8,
        ),
      ],
    ),
    DesignTemplate(
      name: 'Badge',
      description: 'Round brand badge',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _shape(
          nextId,
          ShapeKind.circle,
          y: 200,
          color: theme.accent,
          width: 230,
          height: 230,
        ),
        _text(
          nextId,
          'YOUR BRAND',
          y: 185,
          size: 34,
          color: theme.onAccent,
          font: 'Oswald',
          bold: true,
        ),
        _text(
          nextId,
          'PREMIUM QUALITY',
          y: 228,
          size: 14,
          color: theme.onAccent,
          font: 'Montserrat',
        ),
      ],
    ),
    DesignTemplate(
      name: 'Team Jersey',
      description: 'Name and number',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _text(
          nextId,
          'TEAM NAME',
          y: 95,
          size: 40,
          color: theme.ink,
          font: 'Oswald',
          bold: true,
        ),
        _text(
          nextId,
          '10',
          y: 215,
          size: 170,
          color: theme.ink,
          font: 'Oswald',
          bold: true,
        ),
        _text(
          nextId,
          'PLAYER NAME',
          y: 335,
          size: 28,
          color: theme.ink,
          font: 'Oswald',
        ),
      ],
    ),
    DesignTemplate(
      name: 'Brand Mark',
      description: 'Logo with tagline',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _shape(
          nextId,
          ShapeKind.triangle,
          y: 150,
          color: theme.accent,
          width: 70,
          height: 70,
        ),
        _text(
          nextId,
          'Brand Name',
          y: 235,
          size: 40,
          color: theme.ink,
          font: 'Montserrat',
          bold: true,
        ),
        _text(
          nextId,
          'Your tagline goes here',
          y: 275,
          size: 16,
          color: theme.ink,
          opacity: 0.8,
        ),
      ],
    ),
    DesignTemplate(
      name: 'Quote',
      description: 'Elegant quote',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _text(
          nextId,
          'Make it\nyours.',
          y: 190,
          size: 56,
          color: theme.ink,
          font: 'Playfair Display',
          italic: true,
        ),
        _shape(
          nextId,
          ShapeKind.rectangle,
          y: 285,
          color: theme.accent,
          width: 60,
          height: 6,
        ),
        _text(
          nextId,
          '- Your Name',
          y: 315,
          size: 16,
          color: theme.ink,
          opacity: 0.8,
        ),
      ],
    ),
    DesignTemplate(
      name: 'Star Burst',
      description: 'New collection',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _shape(
          nextId,
          ShapeKind.star,
          y: 190,
          color: theme.accent,
          width: 270,
          height: 270,
        ),
        _text(
          nextId,
          'NEW',
          y: 195,
          size: 80,
          color: theme.onAccent,
          font: 'Bebas Neue',
        ),
        _text(
          nextId,
          'COLLECTION',
          y: 355,
          size: 22,
          color: theme.ink,
          font: 'Montserrat',
          bold: true,
        ),
      ],
    ),
    DesignTemplate(
      name: 'Stacked Type',
      description: 'Three bold lines',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _text(
          nextId,
          'DESIGN',
          y: 130,
          size: 64,
          color: theme.ink,
          font: 'Oswald',
          bold: true,
        ),
        _text(
          nextId,
          'PRODUCE',
          y: 210,
          size: 64,
          color: theme.accent,
          font: 'Oswald',
          bold: true,
        ),
        _text(
          nextId,
          'DELIVER',
          y: 290,
          size: 64,
          color: theme.ink,
          font: 'Oswald',
          bold: true,
        ),
      ],
    ),
    DesignTemplate(
      name: 'Chest Logo',
      description: 'Small pocket print',
      build: (TemplateTheme theme, ElementIdGenerator nextId) =>
          <DesignElement>[
        _shape(
          nextId,
          ShapeKind.circle,
          x: 110,
          y: 120,
          color: theme.accent,
          width: 56,
          height: 56,
        ),
        _text(
          nextId,
          'B',
          x: 110,
          y: 120,
          size: 30,
          color: theme.onAccent,
          font: 'Montserrat',
          bold: true,
        ),
        _text(
          nextId,
          'BRAND',
          x: 195,
          y: 120,
          size: 20,
          color: theme.ink,
          font: 'Montserrat',
          bold: true,
        ),
      ],
    ),
  ];
}
