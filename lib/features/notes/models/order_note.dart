import 'package:flutter/foundation.dart';

/// Who wrote a note.
enum NoteAuthor {
  admin('Admin'),
  manufacturer('Factory');

  const NoteAuthor(this.label);

  final String label;
}

/// What a note is about.
enum NoteKind {
  message('Note'),
  delay('Delay'),
  problem('Problem');

  const NoteKind(this.label);

  final String label;

  /// Delays and problems are issues that someone has to resolve.
  bool get isIssue => this != NoteKind.message;
}

/// Limits for notes, kept in one place so the forms and the service agree.
class NoteRules {
  const NoteRules._();

  static const int minTextLength = 2;
  static const int maxTextLength = 500;
  static const int minDelayDays = 1;
  static const int maxDelayDays = 30;
  static const int maxNotesPerOrder = 200;
}

/// One note on an order, written by the admin or by the factory.
@immutable
class OrderNote {
  const OrderNote({
    required this.id,
    required this.orderId,
    required this.author,
    required this.authorName,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.delayDays,
    this.isResolved = false,
    this.resolvedAt,
  });

  /// Parses a note. Throws [FormatException] for invalid data.
  factory OrderNote.fromMap(Map<String, dynamic> map) {
    final NoteKind kind = _readEnum(NoteKind.values, map, 'kind');
    final int? delayDays = _readOptionalInt(map, 'delayDays');
    if (kind == NoteKind.delay &&
        (delayDays == null ||
            delayDays < NoteRules.minDelayDays ||
            delayDays > NoteRules.maxDelayDays)) {
      throw const FormatException('A delay needs a number of days');
    }
    final String? resolvedAt = _readOptionalString(map, 'resolvedAt');

    return OrderNote(
      id: _readString(map, 'id'),
      orderId: _readString(map, 'orderId'),
      author: _readEnum(NoteAuthor.values, map, 'author'),
      authorName: _readString(map, 'authorName'),
      kind: kind,
      text: _readString(map, 'text'),
      createdAt: DateTime.parse(_readString(map, 'createdAt')),
      delayDays: kind == NoteKind.delay ? delayDays : null,
      isResolved: _readBool(map, 'isResolved'),
      resolvedAt: resolvedAt == null ? null : DateTime.parse(resolvedAt),
    );
  }

  final String id;
  final String orderId;
  final NoteAuthor author;

  /// Name shown for the writer (the factory name, or "Admin").
  final String authorName;
  final NoteKind kind;
  final String text;
  final DateTime createdAt;

  /// Expected delay in days. Only used when [kind] is a delay.
  final int? delayDays;
  final bool isResolved;
  final DateTime? resolvedAt;

  bool get isIssue => kind.isIssue;

  /// A delay or problem that nobody has resolved yet.
  bool get isOpenIssue => isIssue && !isResolved;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'orderId': orderId,
      'author': author.name,
      'authorName': authorName,
      'kind': kind.name,
      'text': text,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'delayDays': delayDays,
      'isResolved': isResolved,
      'resolvedAt': resolvedAt?.toUtc().toIso8601String(),
    };
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static String? _readOptionalString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Invalid "$key"');
  }

  static int? _readOptionalInt(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is num) return value.toInt();
    throw FormatException('Invalid "$key"');
  }

  static bool _readBool(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is bool) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static T _readEnum<T extends Enum>(
    List<T> values,
    Map<String, dynamic> map,
    String key,
  ) {
    final String name = _readString(map, key);
    for (final T value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown "$key" value "$name"');
  }
}
