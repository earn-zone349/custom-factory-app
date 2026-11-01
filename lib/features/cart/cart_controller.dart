import 'package:flutter/foundation.dart';

import 'data/cart_storage.dart';
import 'models/cart_item.dart';

/// Holds the cart in memory and keeps it saved on the device.
/// Every change is saved first and applied after, so a failed save never
/// leaves the screen out of sync with the stored cart.
class CartController extends ChangeNotifier {
  CartController({CartStorage? storage}) : _storage = storage ?? CartStorage();

  static const int maxLines = 50;

  final CartStorage _storage;
  List<CartItem> _items = <CartItem>[];
  bool _isLoaded = false;

  List<CartItem> get items => List<CartItem>.unmodifiable(_items);

  bool get isLoaded => _isLoaded;

  /// Number of lines (different products) in the cart.
  int get itemCount => _items.length;

  int get totalPieces {
    return _items.fold<int>(0, (int sum, CartItem item) => sum + item.quantity);
  }

  /// Sum of the lines that have an estimated price.
  double get estimatedTotal {
    return _items
        .where((CartItem item) => item.hasEstimate)
        .fold<double>(0, (double sum, CartItem item) => sum + item.lineTotal);
  }

  /// True if some lines will be quoted after review.
  bool get hasUnpricedItems {
    return _items.any((CartItem item) => !item.hasEstimate);
  }

  Future<void> load() async {
    try {
      _items = await _storage.read();
    } on Exception catch (error) {
      debugPrint('Could not read the cart: $error');
      _items = <CartItem>[];
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (!_isLoaded) await load();
  }

  Future<void> _persist(List<CartItem> next) async {
    await _storage.write(next);
    _items = next;
    notifyListeners();
  }

  /// Adds an item. Returns false when the cart is full.
  Future<bool> add(CartItem item) async {
    await _ensureLoaded();
    if (_items.length >= maxLines) return false;
    await _persist(<CartItem>[..._items, item]);
    return true;
  }

  Future<void> remove(String id) async {
    await _ensureLoaded();
    await _persist(
      _items.where((CartItem item) => item.id != id).toList(),
    );
  }

  /// Puts a removed item back at [index] (used by Undo).
  Future<void> restore(CartItem item, int index) async {
    await _ensureLoaded();
    if (_items.length >= maxLines) return;
    final List<CartItem> next = List<CartItem>.of(_items);
    next.insert(index.clamp(0, next.length).toInt(), item);
    await _persist(next);
  }

  Future<void> setQuantity(String id, int quantity) async {
    await _ensureLoaded();
    final int index = _items.indexWhere((CartItem item) => item.id == id);
    if (index < 0) return;
    final int safe = quantity
        .clamp(CartItem.minQuantity, CartItem.maxQuantity)
        .toInt();
    final List<CartItem> next = List<CartItem>.of(_items);
    next[index] = next[index].copyWith(quantity: safe);
    await _persist(next);
  }

  Future<void> clear() async {
    await _ensureLoaded();
    await _persist(<CartItem>[]);
  }
}
