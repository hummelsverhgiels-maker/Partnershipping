import 'package:flutter/material.dart';

import '../data/store.dart';
import 'calendar_page.dart';
import 'chat_page.dart';
import 'common.dart';
import 'docs_page.dart';
import 'feed_page.dart';
import 'lists_page.dart';
import 'more_page.dart';
import 'theme.dart';
import 'today_page.dart';

class HomeShell extends StatefulWidget {
  final AppStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Tab(this.label, this.icon, this.selectedIcon);
}

const _tabs = <_Tab>[
  _Tab('Сегодня', Icons.wb_sunny_outlined, Icons.wb_sunny_rounded),
  _Tab('Календарь', Icons.calendar_month_outlined, Icons.calendar_month),
  _Tab('Списки', Icons.checklist_rtl_rounded, Icons.checklist_rtl_rounded),
  _Tab('Лента', Icons.photo_library_outlined, Icons.photo_library_rounded),
  _Tab('Чат', Icons.chat_bubble_outline, Icons.chat_bubble),
  _Tab('Документы', Icons.folder_outlined, Icons.folder_rounded),
  _Tab('Ещё', Icons.grid_view_rounded, Icons.grid_view_rounded),
];

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  // Скрытые вкладки не перерисовываются при каждом обновлении данных:
  // для них хранится последняя собранная версия. Это сильно разгружает телефон.
  final Map<int, Widget> _cache = {};

  static const _chatTab = 4;

  void _go(int i) {
    if (i == _tab) return;
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
      case 3:
        return FeedPage(store: s);
      case _chatTab:
        return ChatPage(store: s, active: active);
      case 5:
        return DocsPage(store: s);
      default:
        return MorePage(store: s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = <Widget>[
      for (var i = 0; i < _tabs.length; i++)
        if (i == _tab)
          (_cache[i] = _page(i, s, active: true))
        else
          (_cache[i] ?? const SizedBox.shrink()),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: s,
        builder: (context, _) => _bar(s),
      ),
    );
  }

  Widget _bar(AppStore s) {
    final unread = _tab == _chatTab ? 0 : s.unreadChat;
    return Container(
      key: const ValueKey('bottom-bar'),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(child: _item(i, i == _chatTab ? unread : 0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, int badge) {
    final t = _tabs[i];
    final sel = i == _tab;
    return PressScale(
      scale: 0.88,
      onTap: () => _go(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: sel ? 46 : 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? kAccentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(
                sel ? t.selectedIcon : t.icon,
                size: 23,
                color: sel ? kAccentDeep : kInkSoft,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                color: sel ? kAccentDeep : kInkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
