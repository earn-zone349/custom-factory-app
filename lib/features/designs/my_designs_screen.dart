import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../editor/data/design_library.dart';
import '../editor/design_editor_screen.dart';
import '../editor/widgets/design_preview.dart';

/// Lists designs saved on this device. Tap one to continue editing.
class MyDesignsScreen extends StatefulWidget {
  const MyDesignsScreen({super.key, required this.isActive, this.library});

  /// True while this tab is visible; the list reloads when it becomes active.
  final bool isActive;
  final DesignLibrary? library;

  @override
  State<MyDesignsScreen> createState() => _MyDesignsScreenState();
}

class _MyDesignsScreenState extends State<MyDesignsScreen> {
  late final DesignLibrary _library = widget.library ?? DesignLibrary();

  List<SavedDesign> _designs = const <SavedDesign>[];
  bool _hasLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant MyDesignsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    try {
      final List<SavedDesign> designs = await _library.loadAll();
      if (!mounted) return;
      setState(() {
        _designs = designs;
        _hasLoaded = true;
        _hasError = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  Future<void> _openDesign(SavedDesign design) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => DesignEditorScreen(
          categoryName: design.document.category,
          baseColor: design.document.baseColor,
          initialElements: design.document.elements,
          designId: design.id,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _confirmDelete(SavedDesign design) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete this design?'),
          content: const Text('This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await _library.delete(design.id);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not delete the design.')),
        );
      return;
    }
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Designs')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return _MessageView(
        icon: Icons.error_outline_rounded,
        title: 'Could not load your designs',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (!_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_designs.isEmpty) {
      return const _MessageView(
        icon: Icons.brush_rounded,
        title: 'No saved designs yet',
        message:
            'Pick a product on Home, design it and tap the check mark to save it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _designs.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.68,
        ),
        itemBuilder: (BuildContext context, int index) {
          final SavedDesign design = _designs[index];
          return _DesignCard(
            design: design,
            onOpen: () => _openDesign(design),
            onDelete: () => _confirmDelete(design),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Saved design';
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.design,
    required this.onOpen,
    required this.onDelete,
  });

  final SavedDesign design;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: DesignPreview(
                    elements: design.document.elements,
                    baseColor: design.document.baseColor,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          design.document.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatDate(design.createdAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryLight,
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
