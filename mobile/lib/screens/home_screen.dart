import 'package:flutter/material.dart';

import 'account_screen.dart';
import 'claims_screen.dart';
import 'pets_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _titles = ['My Pets', 'Claims', 'Account'];

  @override
  Widget build(BuildContext context) {
    // Tabs are rebuilt when selected, so each one shows fresh data.
    final Widget body = switch (_tab) {
      0 => const PetsScreen(),
      1 => const ClaimsScreen(),
      _ => const AccountScreen(),
    };

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets),
            label: 'Pets',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Claims',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
