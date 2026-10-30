import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/core/constants/app_config.dart';
import 'package:custom_factory_app/main.dart';

void main() {
  testWidgets('App shows its name', (WidgetTester tester) async {
    await tester.pumpWidget(const CustomFactoryApp());
    expect(find.text(AppConfig.appName), findsOneWidget);
  });
}
