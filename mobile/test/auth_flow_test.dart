import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csms_mobile/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('LoginPage validation test - empty fields show per-field errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    final loginButton = find.byType(FilledButton);
    expect(loginButton, findsOneWidget);
    await tester.tap(loginButton);
    await tester.pump();

    // After commit #2, validation shows per-field messages instead of a single banner.
    expect(find.text('Username is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('LoginPage fields input test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    // Login page now uses TextFormField (subclass of TextField).
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.at(0), 'linh.counter');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.pump();

    expect(find.text('linh.counter'), findsOneWidget);
    expect(find.text('password123'), findsOneWidget);
  });
}
