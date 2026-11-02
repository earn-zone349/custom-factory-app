import 'dart:async';

import 'package:flutter/material.dart';

import 'core/constants/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/cart/cart_scope.dart';
import 'features/catalog/catalog_scope.dart';
import 'features/manufacturers/manufacturer_scope.dart';
import 'features/splash/splash_screen.dart';

/// App entry point with global error capturing.
Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const CustomFactoryApp());
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

/// Root widget of the application.
class CustomFactoryApp extends StatelessWidget {
  const CustomFactoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (BuildContext context, Widget? child) {
        return CatalogScope(
          child: ManufacturerScope(
            child: CartScope(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
