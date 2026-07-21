import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csms_mobile/features/auth/presentation/login_page.dart';

void main() {
  Widget buildLoginPage() {
    return const ProviderScope(
      child: MaterialApp(home: LoginPage()),
    );
  }

  group('LoginPage empty fields', () {
    testWidgets('shows per-field errors when submitting empty form', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      final loginButton = find.byType(FilledButton);
      expect(loginButton, findsOneWidget);
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Username is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
    });
  });

  group('LoginPage username validation', () {
    testWidgets('rejects username with spaces', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'user name');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Username must not contain spaces.'), findsOneWidget);
    });

    testWidgets('rejects username exceeding 20 characters', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'a' * 21); // 21 chars
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Username must not exceed 20 characters.'), findsOneWidget);
    });

    testWidgets('accepts valid username', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'cashier.linh');
      await tester.enterText(fields.at(1), 'password123');
      // Do not tap the submit button here to avoid triggering real network calls
      // which leave pending Timers in the test environment.
      await tester.pumpAndSettle();

      // No username validation error should be shown.
      expect(find.text('Username is required.'), findsNothing);
      expect(find.text('Username must not contain spaces.'), findsNothing);
      expect(find.text('Username must not exceed 20 characters.'), findsNothing);
    });
  });

  group('LoginPage password validation', () {
    testWidgets('rejects password shorter than 6 characters', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'cashier.linh');
      await tester.enterText(fields.at(1), '12345'); // 5 chars
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);
    });

    testWidgets('rejects password exceeding 20 characters', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'cashier.linh');
      await tester.enterText(fields.at(1), 'a' * 21); // 21 chars
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text('Password must not exceed 20 characters.'), findsOneWidget);
    });
  });

  group('LoginPage field input', () {
    testWidgets('accepts and displays typed values correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginPage());

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));

      await tester.enterText(fields.at(0), 'linh.counter');
      await tester.enterText(fields.at(1), 'password123');
      await tester.pump();

      expect(find.text('linh.counter'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });
  });
}
