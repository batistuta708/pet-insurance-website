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
    // SessionScope sits above MaterialApp so pushed screens can reach it too.
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'Pet Insurance',
        debugShowCheckedModeBanner: false,
        // Brand: gold and black (matches the app icon), always shown in the dark style.
        theme: _goldOnBlackTheme(),
        themeMode: ThemeMode.dark,
        darkTheme: _goldOnBlackTheme(),
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


const _gold = Color(0xFFD4AF37);
const _lightGold = Color(0xFFF7DE8A);
const _black = Color(0xFF111111);

ThemeData _goldOnBlackTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _gold, brightness: Brightness.dark).copyWith(
    primary: _gold,
    onPrimary: Colors.black,
    primaryContainer: const Color(0xFF3A2F0B),
    onPrimaryContainer: _lightGold,
    secondary: _lightGold,
    onSecondary: Colors.black,
    secondaryContainer: const Color(0xFF2A2410),
    onSecondaryContainer: _lightGold,
    surface: _black,
    onSurface: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: _black,
    appBarTheme: const AppBarTheme(backgroundColor: _black, foregroundColor: _gold),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      indicatorColor: _gold,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? Colors.black : Colors.white70,
        ),
      ),
    ),
  );
}
