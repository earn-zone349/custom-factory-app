import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/order_note.dart';

/// Small colored label for a note: "Note", "Delay +3 days" or "Problem".
class NoteKindBadge extends StatelessWidget {
  const NoteKindBadge({super.key, required this.note});

  final OrderNote note;

  /// Background and text color for the kind of note.
  (Color, Color) get _colors {
    return switch (note.kind) {
      NoteKind.message => (AppColors.border, AppColors.textDark),
      NoteKind.delay => (const Color(0xFFFEF3C7), const Color(0xFF92400E)),
      NoteKind.problem => (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error,
        ),
    };
  }

  String get _text {
    if (note.kind != NoteKind.delay) return note.kind.label;
    final int? days = note.delayDays;
    if (days == null) return note.kind.label;
    return 'Delay +$days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = _colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
