import 'package:flutter/material.dart';

import '../data/store.dart';
import 'calendar_page.dart';
import 'settings_page.dart';
import 'shopping_page.dart';
import 'todos_page.dart';

class HomeShell extends StatefulWidget {
  final AppStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = <Widget>[
      CalendarPage(store: s),
      ShoppingPage(store: s),
      TodosPage(store: s),
      SettingsPage(store: s),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Календарь'),
          NavigationDestination(
              icon: Icon(Icons.shopping_basket_outlined),
              selectedIcon: Icon(Icons.shopping_basket),
              label: 'Покупки'),
          NavigationDestination(
              icon: Icon(Icons.checklist_rtl),
              selectedIcon: Icon(Icons.checklist_rtl),
              label: 'Дела'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Настройки'),
        ],
      ),
    );
  }
}
