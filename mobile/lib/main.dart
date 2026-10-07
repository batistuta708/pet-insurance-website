import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'state/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final session = Session(api: ApiClient())..restore();
  runApp(PetInsuranceApp(session: session));
}

class PetInsuranceApp extends StatelessWidget {
  const PetInsuranceApp({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2E7D6B);
    // SessionScope sits above MaterialApp so pushed screens can reach it too.
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'Pet Insurance',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
        darkTheme: ThemeData(
          colorSchemeSeed: seed,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (session.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return session.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
