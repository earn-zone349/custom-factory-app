import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/design_element.dart';
import '../widgets/editor_text_style.dart';
import '../widgets/shape_painter.dart';

/// Thrown when a print file cannot be produced.
class DesignExportException implements Exception {
  const DesignExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Renders a design to a print-ready PNG, independent of the screen size.
/// The background is transparent and no editing frames are drawn.
class DesignExporter {
  const DesignExporter._();

  /// Pixels per canvas unit. 4 gives 1440 x 1680 px.
  static const double defaultScale = 4;

  static Future<Uint8List> renderPng(
    List<DesignElement> elements, {
    double scale = defaultScale,
  }) async {
    if (elements.isEmpty) {
      throw const DesignExportException('Nothing to export');
    }
    final double safeScale = scale.clamp(1.0, 8.0).toDouble();
    final int pixelWidth = (CanvasSpec.width * safeScale).round();
    final int pixelHeight = (CanvasSpec.height * safeScale).round();

    await _waitForFonts();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder)..scale(safeScale);
    final List<ui.Image> decodedImages = <ui.Image>[];

    try {
      for (final DesignElement element in elements) {
        await _paintElement(canvas, element, decodedImages);
      }
      final ui.Picture picture = recorder.endRecording();
      final ui.Image image = await picture.toImage(pixelWidth, pixelHeight);
      try {
        final ByteData? data =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const DesignExportException('Could not encode the image');
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
        picture.dispose();
      }
    } finally {
      for (final ui.Image decoded in decodedImages) {
        decoded.dispose();
      }
    }
  }

  static Future<void> _waitForFonts() async {
    try {
      await GoogleFonts.pendingFonts();
    } on Object {
      // Continue with fallback fonts if a font could not be downloaded.
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    try {
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  static Future<void> _paintElement(
    Canvas canvas,
    DesignElement element,
    List<ui.Image> decodedImages,
  ) async {
    canvas
      ..save()
      ..translate(element.x, element.y)
      ..rotate(element.rotation)
      ..scale(element.scale);

    final bool needsLayer = element.opacity < 1;
    if (needsLayer) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, element.opacity),
      );
    }

    switch (element) {
      case TextElement t:
        _paintText(canvas, t);
      case ShapeElement s:
        canvas.translate(-s.width / 2, -s.height / 2);
        ShapePainter(kind: s.kind, color: s.color)
            .paint(canvas, Size(s.width, s.height));
      case ImageElement i:
        final ui.Image image = await _decode(i.bytes);
        decodedImages.add(image);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          Rect.fromCenter(
            center: Offset.zero,
            width: i.width,
            height: i.height,
          ),
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true,
        );
    }

    if (needsLayer) canvas.restore();
    canvas.restore();
  }

  static void _paintText(Canvas canvas, TextElement element) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: element.text,
        style: EditorTextStyle.resolve(element),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: CanvasSpec.width - 40);
    painter.paint(
      canvas,
      Offset(-painter.width / 2, -painter.height / 2),
    );
    painter.dispose();
  }
}
