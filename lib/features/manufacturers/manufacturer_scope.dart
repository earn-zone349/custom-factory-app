import 'package:flutter/material.dart';

import 'manufacturer_controller.dart';

/// Makes one [ManufacturerController] available to the whole app.
/// Widgets that read it rebuild automatically when the factories change.
class ManufacturerScope extends StatefulWidget {
  const ManufacturerScope({super.key, required this.child, this.controller});

  final Widget child;

  /// Optional controller (used by tests). A default one is created otherwise.
  final ManufacturerController? controller;

  /// The controller, or null if there is no scope above [context].
  static ManufacturerController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ManufacturerInherited>()
        ?.notifier;
  }

  static ManufacturerController of(BuildContext context) {
    final ManufacturerController? controller = maybeOf(context);
    assert(controller != null, 'ManufacturerScope is missing above this widget');
    return controller!;
  }

  @override
  State<ManufacturerScope> createState() => _ManufacturerScopeState();
}

class _ManufacturerScopeState extends State<ManufacturerScope> {
  late final ManufacturerController _controller =
      widget.controller ?? ManufacturerController();

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
    return _ManufacturerInherited(notifier: _controller, child: widget.child);
  }
}

class _ManufacturerInherited extends InheritedNotifier<ManufacturerController> {
  const _ManufacturerInherited({required super.notifier, required super.child});
}
