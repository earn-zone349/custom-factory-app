import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Puts rendered sheet pages into one A4 PDF, one page per image.
class ProductionSheetPdf {
  const ProductionSheetPdf._();

  static Future<Uint8List> build(
    List<Uint8List> pagePngs, {
    String title = 'Production sheet',
  }) async {
    if (pagePngs.isEmpty) {
      throw ArgumentError.value(pagePngs, 'pagePngs', 'At least one page');
    }

    final pw.Document document = pw.Document(title: title);
    for (final Uint8List png in pagePngs) {
      final pw.MemoryImage image = pw.MemoryImage(png);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Image(
              image,
              width: PdfPageFormat.a4.width,
              height: PdfPageFormat.a4.height,
              fit: pw.BoxFit.fill,
            );
          },
        ),
      );
    }
    return document.save();
  }
}
