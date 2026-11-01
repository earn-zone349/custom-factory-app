import 'package:flutter/material.dart';

import 'catalog_controller.dart';

/// Makes one [CatalogController] available to the whole app.
/// Widgets that read it rebuild automatically when the catalog changes.
class CatalogScope extends StatefulWidget {
  const CatalogScope({super.key, required this.child, this.controller});

  final Widget child;

  /// Optional controller (used by tests). A default one is created otherwise.
  final CatalogController? controller;

  /// The catalog, or null if there is no [CatalogScope] above [context].
  static CatalogController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_CatalogInherited>()
        ?.notifier;
  }

  static CatalogController of(BuildContext context) {
    final CatalogController? controller = maybeOf(context);
    assert(controller != null, 'CatalogScope is missing above this widget');
    return controller!;
  }

  @override
  State<CatalogScope> createState() => _CatalogScopeState();
}

class _CatalogScopeState extends State<CatalogScope> {
  late final CatalogController _controller =
      widget.controller ?? CatalogController();

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
    return _CatalogInherited(notifier: _controller, child: widget.child);
  }
}

class _CatalogInherited extends InheritedNotifier<CatalogController> {
  const _CatalogInherited({required super.notifier, required super.child});
}
