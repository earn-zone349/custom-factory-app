import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/shell/main_shell.dart';

void main() {
  testWidgets('Main shell shows bottom navigation labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Design'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
