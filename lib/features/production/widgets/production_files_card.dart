import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../cart/models/cart_item.dart';
import '../../orders/models/order.dart';
import '../models/print_file_exception.dart';
import '../production_files_service.dart';

/// Buttons to create and share the print files and the production sheet of
/// an order. Used by the admin and by the factory.
class ProductionFilesCard extends StatefulWidget {
  const ProductionFilesCard({super.key, required this.order, this.service});

  final Order order;
  final ProductionFilesService? service;

  @override
  State<ProductionFilesCard> createState() => _ProductionFilesCardState();
}

class _ProductionFilesCardState extends State<ProductionFilesCard> {
  late final ProductionFilesService _service =
      widget.service ?? ProductionFilesService();
  bool _isBusy = false;

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Creates files with [createFiles], then opens the share sheet.
  Future<void> _share(
    Future<List<File>> Function() createFiles, {
    required String subject,
    required String mimeType,
  }) async {
    if (_isBusy) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _isBusy = true);
    try {
      final List<File> files = await createFiles();
      if (!mounted) return;
      await Share.shareXFiles(
        files
            .map((File file) => XFile(file.path, mimeType: mimeType))
            .toList(),
        subject: subject,
      );
    } on PrintFileException catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(
        messenger,
        'Could not create the file. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Order order = widget.order;
    final List<CartItem> items = order.items;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Production files',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Print files are high-resolution PNG images with a transparent background. The production sheet is a PDF with one page per item. It has no customer details or prices.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            if (_isBusy) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _isBusy
                  ? null
                  : () => _share(
                        () async => <File>[
                          await _service.createProductionSheet(order),
                        ],
                        subject: 'Production sheet - ${order.id}',
                        mimeType: 'application/pdf',
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Production sheet (PDF)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (int index = 0; index < items.length; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('${items[index].category} x ${items[index].quantity}'),
                subtitle: Text(
                  items[index].designId == null
                      ? 'No design attached'
                      : items[index].summary,
                ),
                trailing: TextButton.icon(
                  onPressed: (_isBusy || items[index].designId == null)
                      ? null
                      : () => _share(
                            () async => <File>[
                              await _service.createPrintFile(order, index),
                            ],
                            subject: 'Print file - ${order.id}',
                            mimeType: 'image/png',
                          ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Print file'),
                ),
              ),
            if (items.length > 1)
              OutlinedButton.icon(
                onPressed: _isBusy
                    ? null
                    : () => _share(
                          () => _service.createAllPrintFiles(order),
                          subject: 'Print files - ${order.id}',
                          mimeType: 'image/png',
                        ),
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('All print files (PNG)'),
              ),
          ],
        ),
      ),
    );
  }
}
