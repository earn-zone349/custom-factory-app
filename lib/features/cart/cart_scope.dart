import 'package:flutter/material.dart';

import 'cart_controller.dart';

/// Makes one [CartController] available to the whole app.
/// Widgets that read it rebuild automatically when the cart changes.
class CartScope extends StatefulWidget {
  const CartScope({super.key, required this.child, this.controller});

  final Widget child;

  /// Optional controller (used by tests). A default one is created otherwise.
  final CartController? controller;

  /// The cart, or null if there is no [CartScope] above [context].
  static CartController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CartInherited>()
        ?.notifier;
  }

  static CartController of(BuildContext context) {
    final CartController? controller = maybeOf(context);
    assert(controller != null, 'CartScope is missing above this widget');
    return controller!;
  }

  @override
  State<CartScope> createState() => _CartScopeState();
}

class _CartScopeState extends State<CartScope> {
  late final CartController _controller =
      widget.controller ?? CartController();

  @override
  void initState() {
    super.initState();
    if (!_controller.isLoaded) _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CartInherited(notifier: _controller, child: widget.child);
  }
}

class _CartInherited extends InheritedNotifier<CartController> {
  const _CartInherited({required super.notifier, required super.child});
}
