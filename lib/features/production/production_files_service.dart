import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/utils/date_formatters.dart';
import '../cart/models/cart_item.dart';
import '../editor/data/design_document.dart';
import '../editor/data/design_exporter.dart';
import '../editor/data/design_storage.dart';
import '../orders/models/order.dart';
import 'models/print_file_exception.dart';
import 'models/production_sheet_page.dart';
import 'production_sheet_pdf.dart';
import 'production_sheet_renderer.dart';

/// Creates the files a factory needs: print-ready PNG files and a
/// production sheet PDF. Files are written to a temporary folder, ready to
/// be shared.
class ProductionFilesService {
  ProductionFilesService({
    DesignStorage? storage,
    Future<Directory> Function()? tempDirectory,
  })  : _storage = storage ?? DesignStorage(),
        _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  /// Resolution of the design picture drawn on the production sheet.
  static const double _sheetPreviewScale = 3;

  final DesignStorage _storage;
  final Future<Directory> Function() _tempDirectory;

  /// File name for the print file of one item, for example
  /// "CF-ABC123_1_mug.png". Only safe characters are used.
  static String fileName(Order order, int itemIndex) {
    final String category = order.items[itemIndex].category
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final String product = category.isEmpty ? 'item' : category;
    return '${_safe(order.id)}_${itemIndex + 1}_$product.png';
  }

  static String _safe(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
  }

  Future<DesignDocument> _loadDesign(CartItem item) async {
    final String? id = item.designId;
    if (id == null) {
      throw PrintFileException(
        '${item.category}: no design is attached to this item',
      );
    }

    DesignDocument document;
    try {
      document = await _storage.load(id);
    } on Exception catch (error) {
      debugPrint('Could not load design $id: $error');
      throw PrintFileException(
        '${item.category}: the design was not found on this phone. It may have been deleted.',
      );
    }
    if (document.elements.isEmpty) {
      throw PrintFileException('${item.category}: the design is empty');
    }
    return document;
  }

  Future<Uint8List> _renderDesign(
    DesignDocument document, {
    double scale = DesignExporter.defaultScale,
  }) async {
    try {
      return await DesignExporter.renderPng(document.elements, scale: scale);
    } on DesignExportException catch (error) {
      throw PrintFileException(error.message);
    }
  }

  /// Renders the print-ready PNG of one item (transparent background).
  Future<File> createPrintFile(Order order, int itemIndex) async {
    if (itemIndex < 0 || itemIndex >= order.items.length) {
      throw ArgumentError.value(itemIndex, 'itemIndex', 'No such item');
    }
    final CartItem item = order.items[itemIndex];
    final DesignDocument document = await _loadDesign(item);
    final Uint8List png = await _renderDesign(document);

    final Directory directory = await _tempDirectory();
    final File file = File('${directory.path}/${fileName(order, itemIndex)}');
    await file.writeAsBytes(png, flush: true);
    return file;
  }

  /// Renders the print file of every item in the order.
  Future<List<File>> createAllPrintFiles(Order order) async {
    final List<File> files = <File>[];
    for (int i = 0; i < order.items.length; i++) {
      files.add(await createPrintFile(order, i));
    }
    return files;
  }

  /// The design picture for a sheet page, or null if the design cannot be
  /// loaded (the sheet is still created, with a note on that page).
  Future<Uint8List?> _tryRenderPreview(CartItem item) async {
    try {
      final DesignDocument document = await _loadDesign(item);
      return await _renderDesign(document, scale: _sheetPreviewScale);
    } on PrintFileException catch (error) {
      debugPrint('Production sheet without a design preview: ${error.message}');
      return null;
    }
  }

  /// Creates the production sheet PDF: one A4 page per order item.
  /// It holds no customer details or prices.
  Future<File> createProductionSheet(Order order) async {
    if (order.items.isEmpty) {
      throw const PrintFileException('This order has no items');
    }

    final List<Uint8List> pages = <Uint8List>[];
    for (int i = 0; i < order.items.length; i++) {
      final CartItem item = order.items[i];
      final Uint8List? design = await _tryRenderPreview(item);
      pages.add(
        await ProductionSheetRenderer.renderPng(
          ProductionSheetPage(
            orderId: order.id,
            orderDate: DateFormatters.dayMonthYear(order.createdAt),
            factoryName: order.manufacturerName ?? 'Not assigned yet',
            itemNumber: i + 1,
            itemCount: order.items.length,
            category: item.category,
            style: item.style,
            size: item.size,
            colorName: item.colorName,
            colorValue: item.colorValue,
            quantity: item.quantity,
            notes: item.notes,
            designPng: design,
          ),
        ),
      );
    }

    final Uint8List pdf = await ProductionSheetPdf.build(
      pages,
      title: 'Production sheet ${order.id}',
    );
    final Directory directory = await _tempDirectory();
    final File file =
        File('${directory.path}/${_safe(order.id)}_production_sheet.pdf');
    await file.writeAsBytes(pdf, flush: true);
    return file;
  }
}
