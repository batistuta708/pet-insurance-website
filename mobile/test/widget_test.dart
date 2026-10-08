// Replaces the counter-app test that `flutter create` would otherwise generate.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  testWidgets('wrong password shows the server message, not "session expired"', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: MockClient((_) async => http.Response(
            '{"error": "Invalid email or password."}',
            401,
            headers: {'content-type': 'application/json'},
          )),
    );
    await tester.pumpWidget(SessionScope(
      session: Session(api: api),
      child: const MaterialApp(home: LoginScreen()),
    ));

    await tester.enterText(find.byType(TextFormField).at(0), 'nobody@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.textContaining('session expired'), findsNothing);
  });

  testWidgets('can switch to the create-account form', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    expect(find.text('Create account'), findsOneWidget);
  });
}
