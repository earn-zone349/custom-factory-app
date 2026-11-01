import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../editor/data/design_document.dart';
import '../../editor/data/design_storage.dart';
import '../../editor/models/design_element.dart';
import '../../editor/widgets/design_preview.dart';

/// Small preview of the saved design attached to an order line.
/// Shows a plain placeholder if the design is missing or unreadable.
class SavedDesignThumbnail extends StatefulWidget {
  const SavedDesignThumbnail({super.key, required this.designId});

  final String? designId;

  @override
  State<SavedDesignThumbnail> createState() => _SavedDesignThumbnailState();
}

class _SavedDesignThumbnailState extends State<SavedDesignThumbnail> {
  Future<DesignDocument>? _future;

  @override
  void initState() {
    super.initState();
    final String? id = widget.designId;
    if (id != null) _future = DesignStorage().load(id);
  }

  @override
  Widget build(BuildContext context) {
    final Future<DesignDocument>? future = _future;
    if (future == null) {
      return const _ThumbPlaceholder(icon: Icons.inventory_2_outlined);
    }

    return FutureBuilder<DesignDocument>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<DesignDocument> snapshot) {
        if (snapshot.hasError) {
          return const _ThumbPlaceholder(
            icon: Icons.image_not_supported_outlined,
          );
        }
        if (!snapshot.hasData) {
          return const _ThumbPlaceholder(icon: Icons.hourglass_empty_rounded);
        }
        final DesignDocument document = snapshot.requireData;
        return DesignPreview(
          elements: document.elements,
          baseColor: document.baseColor,
        );
      },
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: CanvasSpec.width / CanvasSpec.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}
