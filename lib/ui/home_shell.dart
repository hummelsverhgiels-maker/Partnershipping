import 'package:flutter/material.dart';

import '../data/store.dart';
import 'calendar_page.dart';
import 'chat_page.dart';
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

  // Скрытые вкладки не перерисовываются при каждом обновлении данных:
  // для них хранится последняя собранная версия. Это сильно разгружает телефон.
  final Map<int, Widget> _cache = {};

  Widget _page(int i, AppStore s, {required bool active}) {
    switch (i) {
      case 0:
        return CalendarPage(store: s);
      case 1:
        return ShoppingPage(store: s);
      case 2:
        return TodosPage(store: s);
      case 3:
        return ChatPage(store: s, active: active);
      default:
        return SettingsPage(store: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = <Widget>[
      for (var i = 0; i < 5; i++)
        if (i == _tab)
          (_cache[i] = _page(i, s, active: true))
        else
          (_cache[i] ?? const SizedBox.shrink()),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: s,
        builder: (context, _) => _nav(s),
      ),
    );
  }

  Widget _nav(AppStore s) {
    final unread = _tab == 3 ? 0 : s.unreadChat;
    return NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() {
        final old = _tab;
        _tab = i;
        // Покидаемая вкладка запоминается «неактивной».
        if (_cache.containsKey(old)) {
          _cache[old] = _page(old, widget.store, active: false);
        }
      }),
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Календарь',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_basket_outlined),
          selectedIcon: Icon(Icons.shopping_basket),
          label: 'Покупки',
        ),
        NavigationDestination(
          icon: Icon(Icons.checklist_rtl),
          selectedIcon: Icon(Icons.checklist_rtl),
          label: 'Дела',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          selectedIcon: const Icon(Icons.chat_bubble),
          label: 'Чат',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Настройки',
        ),
      ],
    );
  }
}
