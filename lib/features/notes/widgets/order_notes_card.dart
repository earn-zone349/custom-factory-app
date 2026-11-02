import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/date_formatters.dart';
import '../../orders/models/order.dart';
import '../data/note_service.dart';
import '../models/order_note.dart';
import 'note_composer_dialog.dart';
import 'note_kind_badge.dart';

/// The notes of one order, shown to the admin or to the order's factory.
/// The factory can add notes and report delays or problems; the admin can
/// reply and mark issues as resolved.
class OrderNotesCard extends StatefulWidget {
  const OrderNotesCard({
    super.key,
    required this.order,
    required this.viewer,
    this.factoryId,
    this.service,
  });

  final Order order;

  /// Who is looking at the card.
  final NoteAuthor viewer;

  /// The signed-in factory (needed when [viewer] is a factory).
  final String? factoryId;
  final NoteService? service;

  @override
  State<OrderNotesCard> createState() => _OrderNotesCardState();
}

class _OrderNotesCardState extends State<OrderNotesCard> {
  late final NoteService _service = widget.service ?? NoteService();

  List<OrderNote> _notes = const <OrderNote>[];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isBusy = false;

  bool get _isAdmin => widget.viewer == NoteAuthor.admin;

  bool get _canPost {
    if (_isAdmin) return true;
    final String? factoryId = widget.factoryId;
    return factoryId != null &&
        NoteService.canManufacturerPost(widget.order, factoryId);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<OrderNote> notes =
          await _service.listForOrder(widget.order.id);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _isLoading = false;
        _hasError = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _titleFor(NoteKind kind) {
    return switch (kind) {
      NoteKind.message => 'Add a note',
      NoteKind.delay => 'Report a delay',
      NoteKind.problem => 'Report a problem',
    };
  }

  static String _hintFor(NoteKind kind) {
    return switch (kind) {
      NoteKind.message => 'Write your note',
      NoteKind.delay => 'Why will the order be late?',
      NoteKind.problem => 'Describe the problem',
    };
  }

  Future<void> _post(NoteKind kind) async {
    if (_isBusy) return;
    final NoteDraft? draft = await showNoteComposer(
      context,
      title: _titleFor(kind),
      hint: _hintFor(kind),
      askDelayDays: kind == NoteKind.delay,
    );
    if (draft == null || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? factoryId = widget.factoryId;
    setState(() => _isBusy = true);
    try {
      if (_isAdmin) {
        await _service.addAsAdmin(order: widget.order, text: draft.text);
      } else if (factoryId != null) {
        await _service.addAsManufacturer(
          order: widget.order,
          factoryId: factoryId,
          kind: kind,
          text: draft.text,
          delayDays: draft.delayDays,
        );
      } else {
        throw StateError('Your factory is not known');
      }
      await _load();
      _showMessage(messenger, 'Sent');
    } on StateError catch (error) {
      _showMessage(messenger, error.message);
    } on ArgumentError {
      _showMessage(messenger, 'Please check your text and try again.');
    } on Exception {
      _showMessage(messenger, 'Could not send. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resolve(OrderNote note) async {
    if (_isBusy) return;
    final bool confirmed = await confirmResolveIssue(context);
    if (!confirmed || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      await _service.resolve(note.id);
      await _load();
    } on StateError catch (error) {
      _showMessage(messenger, error.message);
    } on Exception {
      _showMessage(messenger, 'Could not update. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final int openCount =
        _notes.where((OrderNote note) => note.isOpenIssue).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Notes and updates',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (openCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$openCount open',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                  onPressed: _isBusy ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildBody(textTheme),
            const SizedBox(height: AppSpacing.md),
            if (_canPost)
              _buildActions()
            else
              Text(
                'Notes are closed because this order is not in progress.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasError) {
      return Row(
        children: <Widget>[
          const Expanded(child: Text('Could not load the notes')),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    if (_notes.isEmpty) {
      return Text(
        'No notes yet.',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      );
    }
    return Column(
      children: <Widget>[
        for (final OrderNote note in _notes)
          _NoteTile(
            note: note,
            isAdmin: _isAdmin,
            isBusy: _isBusy,
            onResolve: () => _resolve(note),
          ),
      ],
    );
  }

  Widget _buildActions() {
    if (_isAdmin) {
      return OutlinedButton.icon(
        onPressed: _isBusy ? null : () => _post(NoteKind.message),
        icon: const Icon(Icons.reply_rounded),
        label: const Text('Reply or add a note'),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _isBusy ? null : () => _post(NoteKind.message),
          icon: const Icon(Icons.edit_note_rounded),
          label: const Text('Add note'),
        ),
        OutlinedButton.icon(
          onPressed: _isBusy ? null : () => _post(NoteKind.delay),
          icon: const Icon(Icons.schedule_rounded),
          label: const Text('Report delay'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: _isBusy ? null : () => _post(NoteKind.problem),
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('Report problem'),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.isAdmin,
    required this.isBusy,
    required this.onResolve,
  });

  final OrderNote note;
  final bool isAdmin;
  final bool isBusy;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool fromAdmin = note.author == NoteAuthor.admin;
    final DateTime? resolvedAt = note.resolvedAt;
    final String statusText = note.isResolved
        ? (resolvedAt == null
            ? 'Resolved'
            : 'Resolved on ${DateFormatters.dayMonthYear(resolvedAt)}')
        : 'Open';
    final Color openColor = note.kind == NoteKind.problem
        ? AppColors.error
        : const Color(0xFFB45309);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fromAdmin
            ? AppColors.background
            : AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: note.isOpenIssue ? openColor : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${note.authorName} · ${DateFormatters.dateTime(note.createdAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (note.kind != NoteKind.message) NoteKindBadge(note: note),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(note.text, style: textTheme.bodyMedium),
          if (note.isIssue) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  note.isResolved
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 18,
                  color: note.isResolved ? AppColors.primary : openColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(statusText, style: textTheme.bodySmall)),
                if (isAdmin && note.isOpenIssue)
                  TextButton(
                    onPressed: isBusy ? null : onResolve,
                    child: const Text('Mark resolved'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
