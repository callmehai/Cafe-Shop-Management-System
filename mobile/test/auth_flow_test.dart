import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csms_mobile/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('LoginPage validation test - empty fields error', (WidgetTester tester) async {
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

    expect(find.text('Please enter your user name and password.'), findsOneWidget);
  });

  testWidgets('LoginPage fields input test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.at(0), 'linh.counter');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.pump();

    expect(find.text('linh.counter'), findsOneWidget);
    expect(find.text('password123'), findsOneWidget);
  });
}
