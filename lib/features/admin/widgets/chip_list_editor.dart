import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../catalog/models/catalog_entry.dart';

/// Edits a list of short texts (such as styles or sizes) as removable chips
/// with a field to add more.
class ChipListEditor extends StatefulWidget {
  const ChipListEditor({
    super.key,
    required this.title,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.helper,
  });

  final String title;
  final String hint;
  final String? helper;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<ChipListEditor> createState() => _ChipListEditorState();
}

class _ChipListEditorState extends State<ChipListEditor> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final String text = _controller.text.trim();
    if (text.isEmpty) return;

    String? error;
    if (text.length > CatalogRules.maxItemLength) {
      error = 'Use at most ${CatalogRules.maxItemLength} characters';
    } else if (widget.values.any(
      (String value) => value.toLowerCase() == text.toLowerCase(),
    )) {
      error = 'Already added';
    } else if (widget.values.length >= CatalogRules.maxListItems) {
      error = 'You can add at most ${CatalogRules.maxListItems} items';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    widget.onChanged(<String>[...widget.values, text]);
    _controller.clear();
    setState(() => _error = null);
  }

  void _remove(String value) {
    widget.onChanged(
      widget.values.where((String item) => item != value).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? helper = widget.helper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (helper != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            helper,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
        if (widget.values.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: widget.values.map((String value) {
              return InputChip(
                label: Text(value),
                onDeleted: () => _remove(value),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  errorText: _error,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              tooltip: 'Add',
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ],
    );
  }
}
