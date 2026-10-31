import 'dart:typed_data' as typed;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import 'models/design_element.dart';
import 'models/design_template.dart';

/// Holds the editor state: elements, selection and undo/redo history.
class DesignController extends ChangeNotifier {
  DesignController({this.defaultTextColor = Colors.black});

  static const int maxElements = 100;
  static const int _maxHistory = 50;

  /// Color given to newly added text (chosen for contrast with the product).
  final Color defaultTextColor;

  final List<DesignElement> _elements = <DesignElement>[];
  final List<List<DesignElement>> _undoStack = <List<DesignElement>>[];
  final List<List<DesignElement>> _redoStack = <List<DesignElement>>[];

  List<DesignElement>? _pending;
  String? _selectedId;
  int _idCounter = 0;

  List<DesignElement> get elements =>
      List<DesignElement>.unmodifiable(_elements);

  String? get selectedId => _selectedId;

  DesignElement? get selected => _find(_selectedId);

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  bool get isFull => _elements.length >= maxElements;

  DesignElement? _find(String? id) {
    if (id == null) return null;
    for (final DesignElement element in _elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  int _indexOf(String id) {
    return _elements.indexWhere((DesignElement e) => e.id == id);
  }

  String _nextId() => 'element_${_idCounter++}';

  void _pushUndo(List<DesignElement> snapshot) {
    _undoStack.add(snapshot);
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
  }

  void _recordHistory() {
    _pushUndo(List<DesignElement>.of(_elements));
    _redoStack.clear();
  }

  static bool _sameElements(List<DesignElement> a, List<DesignElement> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /// Adds a text layer. Returns false if the text is empty or the canvas full.
  bool addText(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || isFull) return false;
    _recordHistory();
    final String id = _nextId();
    _elements.add(
      TextElement(
        id: id,
        x: CanvasSpec.width / 2,
        y: CanvasSpec.height / 2,
        text: trimmed,
        color: defaultTextColor,
      ),
    );
    _selectedId = id;
    notifyListeners();
    return true;
  }

  /// Adds a shape layer. Returns false if the canvas is full.
  bool addShape(ShapeKind kind) {
    if (isFull) return false;
    _recordHistory();
    final String id = _nextId();
    _elements.add(
      ShapeElement(
        id: id,
        x: CanvasSpec.width / 2,
        y: CanvasSpec.height / 2,
        kind: kind,
        color: AppColors.primary,
      ),
    );
    _selectedId = id;
    notifyListeners();
    return true;
  }

  /// Adds a picked image sized to fit the canvas (longest side 200 units).
  /// Returns false for invalid data or when the canvas is full.
  bool addImage(typed.Uint8List bytes, double aspectRatio) {
    if (bytes.isEmpty || !aspectRatio.isFinite || aspectRatio <= 0 || isFull) {
      return false;
    }
    const double longestSide = 200;
    final double width =
        aspectRatio >= 1 ? longestSide : longestSide * aspectRatio;
    final double height =
        aspectRatio >= 1 ? longestSide / aspectRatio : longestSide;
    _recordHistory();
    final String id = _nextId();
    _elements.add(
      ImageElement(
        id: id,
        x: CanvasSpec.width / 2,
        y: CanvasSpec.height / 2,
        bytes: bytes,
        width: width,
        height: height,
      ),
    );
    _selectedId = id;
    notifyListeners();
    return true;
  }

  /// Replaces the whole design with a template. Returns false if the
  /// template produces nothing. The change can be undone.
  bool applyTemplate(DesignTemplate template, TemplateTheme theme) {
    final List<DesignElement> built = template.build(theme, _nextId);
    if (built.isEmpty || built.length > maxElements) return false;
    _recordHistory();
    _elements
      ..clear()
      ..addAll(built);
    _selectedId = null;
    notifyListeners();
    return true;
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Replaces one element. Set [recordHistory] to false for live changes
  /// (sliders, gestures) and wrap them in [beginTransform]/[endTransform].
  void updateElement(
    String id,
    DesignElement Function(DesignElement current) change, {
    bool recordHistory = true,
  }) {
    final int index = _indexOf(id);
    if (index < 0) return;
    if (recordHistory) _recordHistory();
    _elements[index] = change(_elements[index]);
    notifyListeners();
  }

  /// Starts a continuous change (drag, pinch, slider) as one history step.
  void beginTransform() {
    _pending = List<DesignElement>.of(_elements);
  }

  /// Applies a live move/scale/rotate while keeping the element on canvas.
  void transformLive(
    String id, {
    double dx = 0,
    double dy = 0,
    double? scale,
    double? rotation,
  }) {
    updateElement(
      id,
      (DesignElement e) => e.transformed(
        x: (e.x + dx).clamp(0.0, CanvasSpec.width).toDouble(),
        y: (e.y + dy).clamp(0.0, CanvasSpec.height).toDouble(),
        scale: scale,
        rotation: rotation,
      ),
      recordHistory: false,
    );
  }

  /// Finishes a continuous change and records it only if something changed.
  void endTransform() {
    final List<DesignElement>? before = _pending;
    _pending = null;
    if (before == null) return;
    if (!_sameElements(before, _elements)) {
      _pushUndo(before);
      _redoStack.clear();
    }
    notifyListeners();
  }

  void deleteSelected() {
    final String? id = _selectedId;
    if (id == null) return;
    final int index = _indexOf(id);
    if (index < 0) return;
    _recordHistory();
    _elements.removeAt(index);
    _selectedId = null;
    notifyListeners();
  }

  void duplicateSelected() {
    final DesignElement? current = selected;
    if (current == null || isFull) return;
    _recordHistory();
    final DesignElement copy = current.duplicated(newId: _nextId());
    _elements.add(copy);
    _selectedId = copy.id;
    notifyListeners();
  }

  void moveForward() => _moveSelected(1);

  void moveBackward() => _moveSelected(-1);

  void _moveSelected(int delta) {
    final String? id = _selectedId;
    if (id == null) return;
    final int from = _indexOf(id);
    final int to = from + delta;
    if (from < 0 || to < 0 || to >= _elements.length) return;
    _recordHistory();
    final DesignElement moved = _elements.removeAt(from);
    _elements.insert(to, moved);
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<DesignElement>.of(_elements));
    _restore(_undoStack.removeLast());
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _pushUndo(List<DesignElement>.of(_elements));
    _restore(_redoStack.removeLast());
  }

  void _restore(List<DesignElement> snapshot) {
    _elements
      ..clear()
      ..addAll(snapshot);
    if (_find(_selectedId) == null) _selectedId = null;
    notifyListeners();
  }
}
