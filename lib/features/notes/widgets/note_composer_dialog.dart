import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../models/order_note.dart';

/// What the writer typed in the note dialog.
@immutable
class NoteDraft {
  const NoteDraft({required this.text, this.delayDays});

  final String text;

  /// Chosen delay in days (only when the dialog asked for it).
  final int? delayDays;
}

/// Shows the dialog to write a note. Set [askDelayDays] to also ask how many
/// days late the order will be. Returns null if cancelled.
Future<NoteDraft?> showNoteComposer(
  BuildContext context, {
  required String title,
  required String hint,
  bool askDelayDays = false,
}) {
  return showDialog<NoteDraft>(
    context: context,
    builder: (BuildContext dialogContext) {
      return _NoteComposerDialog(
        title: title,
        hint: hint,
        askDelayDays: askDelayDays,
      );
    },
  );
}

/// Asks the admin to confirm that an issue is resolved.
Future<bool> confirmResolveIssue(BuildContext context) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Mark as resolved?'),
        content: const Text('The factory will see this issue as resolved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Mark resolved'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _NoteComposerDialog extends StatefulWidget {
  const _NoteComposerDialog({
    required this.title,
    required this.hint,
    required this.askDelayDays,
  });

  final String title;
  final String hint;
  final bool askDelayDays;

  @override
  State<_NoteComposerDialog> createState() => _NoteComposerDialogState();
}

class _NoteComposerDialogState extends State<_NoteComposerDialog> {
  static const List<int> _dayOptions = <int>[1, 2, 3, 5, 7, 10, 14, 21, 30];

  final TextEditingController _controller = TextEditingController();
  int _days = 2;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text.trim();
    if (text.length < NoteRules.minTextLength) {
      setState(() {
        _error = 'Write at least ${NoteRules.minTextLength} characters';
      });
      return;
    }
    Navigator.of(context).pop(
      NoteDraft(text: text, delayDays: widget.askDelayDays ? _days : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (widget.askDelayDays) ...<Widget>[
              Text(
                'Expected delay',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: _dayOptions.map((int days) {
                  return ChoiceChip(
                    label: Text('$days day${days == 1 ? '' : 's'}'),
                    selected: days == _days,
                    selectedColor: AppColors.primaryLight,
                    onSelected: (_) => setState(() => _days = days),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: NoteRules.maxTextLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.hint,
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
  }
}
