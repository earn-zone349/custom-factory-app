import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/design_element.dart';

/// Fonts offered in the editor (downloaded on demand by google_fonts).
class EditorFonts {
  const EditorFonts._();

  static const List<String> families = <String>[
    'Poppins',
    'Montserrat',
    'Oswald',
    'Bebas Neue',
    'Pacifico',
    'Lobster',
    'Playfair Display',
    'Roboto Mono',
  ];
}

/// Builds the TextStyle of a text element.
class EditorTextStyle {
  const EditorTextStyle._();

  static TextStyle resolve(TextElement element) {
    final TextStyle base = TextStyle(
      fontSize: element.fontSize,
      color: element.color,
      fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      height: 1.15,
    );
    try {
      return GoogleFonts.getFont(element.fontFamily, textStyle: base);
    } on Object {
      // Falls back to the default font if the font cannot be loaded.
      return base;
    }
  }
}
