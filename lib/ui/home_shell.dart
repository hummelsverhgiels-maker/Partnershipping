import 'package:flutter/material.dart';

import '../data/store.dart';
import 'calendar_page.dart';
import 'lists_page.dart';
import 'more_page.dart';
import 'today_page.dart';
import 'chat_page.dart';

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

  static const _chatTab = 3;

  void _go(int i) {
    setState(() {
      final old = _tab;
      _tab = i;
      // Покидаемая вкладка запоминается «неактивной».
      if (_cache.containsKey(old)) {
        _cache[old] = _page(old, widget.store, active: false);
      }
    });
  }

  Widget _page(int i, AppStore s, {required bool active}) {
    switch (i) {
      case 0:
        return TodayPage(store: s, onOpenTab: _go);
      case 1:
        return CalendarPage(store: s);
      case 2:
        return ListsPage(store: s);
      case _chatTab:
        return ChatPage(store: s, active: active);
      default:
        return MorePage(store: s);
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
    final unread = _tab == _chatTab ? 0 : s.unreadChat;
    return NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: _go,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.wb_sunny_outlined),
          selectedIcon: Icon(Icons.wb_sunny_rounded),
          label: 'Сегодня',
        ),
        const NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: 'Календарь',
        ),
        const NavigationDestination(
          icon: Icon(Icons.checklist_rtl_rounded),
          selectedIcon: Icon(Icons.checklist_rtl_rounded),
          label: 'Списки',
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
        const NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          selectedIcon: Icon(Icons.grid_view_rounded),
          label: 'Ещё',
        ),
      ],
    );
  }
}
