import '../../orders/data/order_service.dart';
import '../../orders/models/order.dart';
import '../models/order_note.dart';
import 'note_storage.dart';

/// Rules and actions for notes on orders.
class NoteService {
  NoteService({NoteStorage? storage, DateTime Function()? clock})
      : _storage = storage ?? NoteStorage(),
        _clock = clock ?? DateTime.now;

  /// While an order is in one of these statuses, its factory can write to it.
  static const Set<OrderStatus> _activeStatuses = <OrderStatus>{
    OrderStatus.confirmed,
    OrderStatus.inProduction,
    OrderStatus.qualityCheck,
    OrderStatus.outForDelivery,
  };

  final NoteStorage _storage;
  final DateTime Function() _clock;
  int _counter = 0;

  /// True if [factoryId] may add notes to [order]: the order is assigned to
  /// that factory and is still being worked on.
  static bool canManufacturerPost(Order order, String factoryId) {
    return OrderService.isVisibleToFactory(order, factoryId) &&
        _activeStatuses.contains(order.status);
  }

  /// The delays and problems that still need attention, newest first.
  /// Notes of cancelled or unknown orders are left out.
  static List<OrderNote> openIssuesFor(
    List<Order> orders,
    List<OrderNote> notes,
  ) {
    final Map<String, Order> byId = <String, Order>{
      for (final Order order in orders) order.id: order,
    };
    final List<OrderNote> open = notes.where((OrderNote note) {
      final Order? order = byId[note.orderId];
      return note.isOpenIssue &&
          order != null &&
          order.status != OrderStatus.cancelled;
    }).toList();
    return open.reversed.toList();
  }

  /// All notes of one order, oldest first.
  Future<List<OrderNote>> listForOrder(String orderId) async {
    final List<OrderNote> all = await _storage.read();
    return all.where((OrderNote note) => note.orderId == orderId).toList();
  }

  /// Every note, oldest first.
  Future<List<OrderNote>> listAll() => _storage.read();

  /// Adds a note written by a factory. Throws StateError if the order is not
  /// the factory's or is no longer being worked on, and ArgumentError for an
  /// invalid text or delay.
  Future<OrderNote> addAsManufacturer({
    required Order order,
    required String factoryId,
    required NoteKind kind,
    required String text,
    int? delayDays,
  }) async {
    if (!canManufacturerPost(order, factoryId)) {
      throw StateError('You cannot add notes to this order');
    }
    return _add(
      order: order,
      author: NoteAuthor.manufacturer,
      authorName: order.manufacturerName ?? 'Factory',
      kind: kind,
      text: text,
      delayDays: delayDays,
    );
  }

  /// Adds a plain note written by the admin team.
  Future<OrderNote> addAsAdmin({required Order order, required String text}) {
    return _add(
      order: order,
      author: NoteAuthor.admin,
      authorName: 'Admin',
      kind: NoteKind.message,
      text: text,
    );
  }

  Future<OrderNote> _add({
    required Order order,
    required NoteAuthor author,
    required String authorName,
    required NoteKind kind,
    required String text,
    int? delayDays,
  }) async {
    final String cleaned = text.trim();
    if (cleaned.length < NoteRules.minTextLength ||
        cleaned.length > NoteRules.maxTextLength) {
      throw ArgumentError.value(
        text,
        'text',
        'A note needs ${NoteRules.minTextLength} to ${NoteRules.maxTextLength} characters',
      );
    }
    if (kind == NoteKind.delay) {
      if (delayDays == null ||
          delayDays < NoteRules.minDelayDays ||
          delayDays > NoteRules.maxDelayDays) {
        throw ArgumentError.value(
          delayDays,
          'delayDays',
          'A delay needs ${NoteRules.minDelayDays} to ${NoteRules.maxDelayDays} days',
        );
      }
    } else if (delayDays != null) {
      throw ArgumentError.value(
        delayDays,
        'delayDays',
        'Only a delay can have a number of days',
      );
    }

    // An unreadable notes file is backed up and replaced when the note is
    // saved, so it must not stop a new note from being added.
    List<OrderNote> existing;
    try {
      existing = await listForOrder(order.id);
    } on FormatException {
      existing = const <OrderNote>[];
    }
    if (existing.length >= NoteRules.maxNotesPerOrder) {
      throw StateError('This order has too many notes');
    }

    final DateTime now = _clock();
    final OrderNote note = OrderNote(
      id: 'note_${now.microsecondsSinceEpoch}_${_counter++}',
      orderId: order.id,
      author: author,
      authorName: authorName,
      kind: kind,
      text: cleaned,
      createdAt: now,
      delayDays: delayDays,
    );
    await _storage.add(note);
    return note;
  }

  /// Marks a delay or problem as resolved.
  /// Throws StateError if the note does not exist.
  Future<void> resolve(String noteId) async {
    final bool changed = await _storage.markResolved(noteId, _clock());
    if (!changed) throw StateError('This note was not found');
  }
}
