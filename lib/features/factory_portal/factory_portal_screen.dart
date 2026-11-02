import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../manufacturers/manufacturer_controller.dart';
import '../manufacturers/manufacturer_scope.dart';
import '../manufacturers/models/manufacturer.dart';
import '../orders/data/order_service.dart';
import 'data/factory_session_storage.dart';
import 'factory_orders_screen.dart';

/// Entry point of the factory panel. A factory picks who it is once, then
/// sees its own orders.
class FactoryPortalScreen extends StatefulWidget {
  const FactoryPortalScreen({super.key, this.service, this.sessionStorage});

  final OrderService? service;
  final FactorySessionStorage? sessionStorage;

  @override
  State<FactoryPortalScreen> createState() => _FactoryPortalScreenState();
}

class _FactoryPortalScreenState extends State<FactoryPortalScreen> {
  late final OrderService _service = widget.service ?? OrderService();
  late final FactorySessionStorage _session =
      widget.sessionStorage ?? FactorySessionStorage();

  String? _factoryId;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    String? id;
    try {
      id = await _session.readFactoryId();
    } on Exception catch (error) {
      debugPrint('Could not read the factory session: $error');
    }
    if (!mounted) return;
    setState(() {
      _factoryId = id;
      _hasLoaded = true;
    });
  }

  /// Chooses a factory (or clears the choice with null). Saving is best
  /// effort: if it fails the choice still works until the app closes.
  Future<void> _select(String? id) async {
    setState(() => _factoryId = id);
    try {
      await _session.saveFactoryId(id);
    } on Exception catch (error) {
      debugPrint('Could not save the factory choice: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasLoaded) {
      return const Scaffold(
        appBar: AppBar(title: Text('Factory panel')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ManufacturerController factories = ManufacturerScope.of(context);
    final String? id = _factoryId;
    final Manufacturer? factory = id == null ? null : factories.byId(id);

    if (factory == null) {
      return _FactoryChooser(
        factories: factories.entries,
        isLoaded: factories.isLoaded,
        onSelected: (Manufacturer chosen) => _select(chosen.id),
      );
    }
    return FactoryOrdersScreen(
      factory: factory,
      service: _service,
      onSwitchFactory: () => _select(null),
    );
  }
}

class _FactoryChooser extends StatelessWidget {
  const _FactoryChooser({
    required this.factories,
    required this.isLoaded,
    required this.onSelected,
  });

  final List<Manufacturer> factories;
  final bool isLoaded;
  final ValueChanged<Manufacturer> onSelected;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget body;
    if (!isLoaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (factories.isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No factories yet. The admin can add one from Admin panel, then Factories.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            'Choose your factory to see its orders.',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Real sign-in comes with the account system.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final Manufacturer factory in factories)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.factory_outlined,
                  color: AppColors.primary,
                ),
                title: Text(factory.name),
                subtitle: Text(
                  factory.isActive
                      ? factory.district
                      : '${factory.district} · Inactive',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onSelected(factory),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Factory panel')),
      body: body,
    );
  }
}
