import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatters.dart';
import '../notes/data/note_service.dart';
import '../notes/models/order_note.dart';
import '../notes/widgets/note_composer_dialog.dart';
import '../notes/widgets/note_kind_badge.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import 'admin_order_detail_screen.dart';

/// An open delay or problem together with the order it belongs to.
class _IssueEntry {
  const _IssueEntry({required this.note, required this.order});

  final OrderNote note;
  final Order order;
}

/// Delays and problems reported on orders that nobody has resolved yet.
class AdminIssuesScreen extends StatefulWidget {
  const AdminIssuesScreen({super.key, required this.service, this.noteService});

  final OrderService service;
  final NoteService? noteService;

  @override
  State<AdminIssuesScreen> createState() => _AdminIssuesScreenState();
}

class _AdminIssuesScreenState extends State<AdminIssuesScreen> {
  late final NoteService _noteService = widget.noteService ?? NoteService();

  List<_IssueEntry> _issues = const <_IssueEntry>[];
  bool _hasLoaded = false;
  bool _hasError = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Order> orders = await widget.service.listOrders();
      final List<OrderNote> notes = await _noteService.listAll();
      final Map<String, Order> byId = <String, Order>{
        for (final Order order in orders) order.id: order,
      };
      final List<_IssueEntry> entries = <_IssueEntry>[
        for (final OrderNote note in NoteService.openIssuesFor(orders, notes))
          if (byId[note.orderId] case final Order order)
            _IssueEntry(note: note, order: order),
      ];
      if (!mounted) return;
      setState(() {
        _issues = entries;
        _hasLoaded = true;
        _hasError = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  Future<void> _openOrder(Order order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminOrderDetailScreen(
          order: order,
          service: widget.service,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _resolve(_IssueEntry entry) async {
    if (_isBusy) return;
    final bool confirmed = await confirmResolveIssue(context);
    if (!confirmed || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isBusy = true);
    try {
      await _noteService.resolve(entry.note.id);
      await _load();
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not update. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Issues and delays')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Could not load the issues'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_issues.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No open issues. Delays and problems reported by factories appear here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _issues.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final _IssueEntry entry = _issues[index];
          return _IssueCard(
            entry: entry,
            isBusy: _isBusy,
            onOpen: () => _openOrder(entry.order),
            onResolve: () => _resolve(entry),
          );
        },
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.entry,
    required this.isBusy,
    required this.onOpen,
    required this.onResolve,
  });

  final _IssueEntry entry;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final OrderNote note = entry.note;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.order.id,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                NoteKindBadge(note: note),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${note.authorName} · ${DateFormatters.dateTime(note.createdAt)}',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(note.text, style: textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpen,
                    child: const Text('Open order'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isBusy ? null : onResolve,
                    child: const Text('Resolved'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
