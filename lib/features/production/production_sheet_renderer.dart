import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../editor/models/design_element.dart';
import 'models/print_file_exception.dart';
import 'models/production_sheet_page.dart';

/// Draws one production sheet page as a PNG (A4 at 150 dots per inch).
/// Text uses the device font, so Bangla notes are shown correctly.
class ProductionSheetRenderer {
  const ProductionSheetRenderer._();

  static const double pageWidth = 1240;
  static const double pageHeight = 1754;

  static const double _margin = 70;
  static const double _contentWidth = pageWidth - _margin * 2;
  static const double _headerHeight = 190;
  static const double _designBoxHeight = 560;
  static const double _designBoxWidth =
      _designBoxHeight * CanvasSpec.width / CanvasSpec.height;

  static Future<Uint8List> renderPng(ProductionSheetPage page) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    ui.Image? design;
    try {
      final Uint8List? designBytes = page.designPng;
      if (designBytes != null) design = await _decode(designBytes);
      _paintPage(canvas, page, design);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image =
          await picture.toImage(pageWidth.round(), pageHeight.round());
      try {
        final ByteData? data =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          throw const PrintFileException(
            'Could not create the production sheet',
          );
        }
        return data.buffer.asUint8List();
      } finally {
        image.dispose();
        picture.dispose();
      }
    } finally {
      design?.dispose();
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

  static void _paintPage(
    Canvas canvas,
    ProductionSheetPage page,
    ui.Image? design,
  ) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, pageWidth, pageHeight),
      Paint()..color = Colors.white,
    );
    _paintHeader(canvas, page);
    _paintFacts(canvas, page);
    _paintProduct(canvas, page);
    _paintNotes(canvas, page);
    _paintDesign(canvas, page, design);
    _paintFooter(canvas, page);
  }

  static void _paintHeader(Canvas canvas, ProductionSheetPage page) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, pageWidth, _headerHeight),
      Paint()..color = AppColors.primary,
    );
    _text(
      canvas,
      'PRODUCTION SHEET',
      const Offset(_margin, 40),
      maxWidth: 760,
      size: 46,
      color: Colors.white,
      bold: true,
    );
    _text(
      canvas,
      page.orderId,
      const Offset(_margin, 112),
      maxWidth: 760,
      size: 36,
      color: Colors.white,
    );
    _text(
      canvas,
      'Item ${page.itemNumber} of ${page.itemCount}',
      const Offset(pageWidth - _margin - 340, 60),
      maxWidth: 340,
      size: 38,
      color: Colors.white,
      bold: true,
      align: TextAlign.right,
    );
  }

  static void _paintFacts(Canvas canvas, ProductionSheetPage page) {
    const double top = 235;
    const double factoryX = pageWidth / 2;
    _label(canvas, 'ORDER DATE', const Offset(_margin, top));
    _text(
      canvas,
      page.orderDate,
      const Offset(_margin, top + 38),
      maxWidth: 480,
      size: 34,
    );
    _label(canvas, 'FACTORY', const Offset(factoryX, top));
    _text(
      canvas,
      page.factoryName,
      const Offset(factoryX, top + 38),
      maxWidth: pageWidth - _margin - factoryX,
      size: 34,
      bold: true,
    );
    _divider(canvas, 345);
  }

  static void _paintProduct(Canvas canvas, ProductionSheetPage page) {
    _text(
      canvas,
      page.category,
      const Offset(_margin, 375),
      maxWidth: _contentWidth,
      size: 64,
      bold: true,
    );

    double y = 480;
    final String? style = page.style;
    if (style != null) y = _spec(canvas, 'STYLE', style, y);
    final String? size = page.size;
    if (size != null) y = _spec(canvas, 'SIZE', size, y);
    _paintColor(canvas, page, y);
    _paintQuantity(canvas, page.quantity);
  }

  /// A label with its value underneath. Returns where the next row starts.
  static double _spec(Canvas canvas, String label, String value, double y) {
    _label(canvas, label, Offset(_margin, y));
    _text(
      canvas,
      value,
      Offset(_margin, y + 34),
      maxWidth: 640,
      size: 38,
    );
    return y + 100;
  }

  static void _paintColor(Canvas canvas, ProductionSheetPage page, double y) {
    _label(canvas, 'COLOR', Offset(_margin, y));
    final Offset center = Offset(_margin + 20, y + 58);
    canvas.drawCircle(center, 20, Paint()..color = Color(page.colorValue));
    canvas.drawCircle(
      center,
      20,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _text(
      canvas,
      page.colorName,
      Offset(_margin + 56, y + 34),
      maxWidth: 560,
      size: 38,
    );
  }

  static void _paintQuantity(Canvas canvas, int quantity) {
    const Rect box = Rect.fromLTWH(pageWidth - _margin - 400, 480, 400, 300);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(24)),
      Paint()..color = AppColors.primaryLight,
    );

    final String text = '$quantity';
    final double numberSize = text.length <= 4 ? 110 : (text.length <= 6 ? 80 : 60);
    _text(
      canvas,
      'QUANTITY',
      Offset(box.left, box.top + 36),
      maxWidth: box.width,
      size: 28,
      color: AppColors.primaryDark,
      bold: true,
      align: TextAlign.center,
    );
    _text(
      canvas,
      text,
      Offset(box.left, box.top + 100),
      maxWidth: box.width,
      size: numberSize,
      color: AppColors.primaryDark,
      bold: true,
      align: TextAlign.center,
    );
    _text(
      canvas,
      'pieces',
      Offset(box.left, box.top + 235),
      maxWidth: box.width,
      size: 28,
      color: AppColors.primaryDark,
      align: TextAlign.center,
    );
  }

  static void _paintNotes(Canvas canvas, ProductionSheetPage page) {
    const double top = 830;
    _label(canvas, 'NOTES', const Offset(_margin, top));
    final String notes = page.notes.trim();
    _text(
      canvas,
      notes.isEmpty ? 'No special notes' : notes,
      const Offset(_margin, top + 40),
      maxWidth: _contentWidth,
      size: 30,
      color: notes.isEmpty ? AppColors.textMuted : AppColors.textDark,
      maxLines: 4,
    );
    _divider(canvas, 1025);
  }

  static void _paintDesign(
    Canvas canvas,
    ProductionSheetPage page,
    ui.Image? design,
  ) {
    _label(canvas, 'DESIGN PREVIEW', const Offset(_margin, 1050));

    const Rect box = Rect.fromLTWH(
      (pageWidth - _designBoxWidth) / 2,
      1100,
      _designBoxWidth,
      _designBoxHeight,
    );
    final RRect rounded =
        RRect.fromRectAndRadius(box, const Radius.circular(24));
    final Color productColor = Color(page.colorValue);

    canvas.save();
    canvas.clipRRect(rounded);
    canvas.drawRect(box, Paint()..color = productColor);
    if (design != null) {
      canvas.drawImageRect(
        design,
        Rect.fromLTWH(
          0,
          0,
          design.width.toDouble(),
          design.height.toDouble(),
        ),
        box,
        Paint()
          ..filterQuality = FilterQuality.high
          ..isAntiAlias = true,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (design == null) {
      final bool darkProduct =
          ThemeData.estimateBrightnessForColor(productColor) == Brightness.dark;
      _text(
        canvas,
        'Design not available on this phone',
        Offset(box.left + 30, box.center.dy - 30),
        maxWidth: box.width - 60,
        size: 30,
        color: darkProduct ? Colors.white70 : AppColors.textMuted,
        align: TextAlign.center,
        maxLines: 3,
      );
    }
  }

  static void _paintFooter(Canvas canvas, ProductionSheetPage page) {
    _text(
      canvas,
      AppConfig.appName,
      const Offset(_margin, 1700),
      maxWidth: 700,
      size: 24,
      color: AppColors.textMuted,
    );
    _text(
      canvas,
      'Page ${page.itemNumber} of ${page.itemCount}',
      const Offset(pageWidth - _margin - 300, 1700),
      maxWidth: 300,
      size: 24,
      color: AppColors.textMuted,
      align: TextAlign.right,
    );
  }

  static void _divider(Canvas canvas, double y) {
    canvas.drawLine(
      Offset(_margin, y),
      Offset(pageWidth - _margin, y),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 2,
    );
  }

  static void _label(Canvas canvas, String text, Offset offset) {
    _text(
      canvas,
      text,
      offset,
      maxWidth: 520,
      size: 24,
      color: AppColors.textMuted,
      bold: true,
    );
  }

  /// Draws text inside a box of [maxWidth] starting at [offset]. Returns the
  /// height used. Long text is cut with "..." after [maxLines] lines.
  static double _text(
    Canvas canvas,
    String text,
    Offset offset, {
    required double maxWidth,
    double size = 30,
    Color color = AppColors.textDark,
    bool bold = false,
    TextAlign align = TextAlign.left,
    int maxLines = 1,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          height: 1.2,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(
        minWidth: align == TextAlign.left ? 0 : maxWidth,
        maxWidth: maxWidth,
      );
    painter.paint(canvas, offset);
    final double height = painter.height;
    painter.dispose();
    return height;
  }
}
