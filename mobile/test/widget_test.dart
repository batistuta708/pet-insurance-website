// Replaces the counter-app test that `flutter create` would otherwise generate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_insurance/api/api_client.dart';
import 'package:pet_insurance/screens/login_screen.dart';
import 'package:pet_insurance/state/session.dart';

void main() {
  Widget wrap(Widget child) => SessionScope(
        session: Session(api: ApiClient(baseUrl: 'http://test/api/v1')),
        child: MaterialApp(home: child),
      );

  testWidgets('login screen validates input before calling the server', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    expect(find.text('Pet Insurance'), findsOneWidget);
    await tester.tap(find.text('Log in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('can switch to the create-account form', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    expect(find.text('Create account'), findsOneWidget);
  });
}
