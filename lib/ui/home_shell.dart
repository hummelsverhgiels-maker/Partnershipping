import 'package:flutter/material.dart';

import '../data/store.dart';
import 'calendar_page.dart';
import 'chat_page.dart';
import 'common.dart';
import 'docs_page.dart';
import 'feed_page.dart';
import 'kiss_page.dart';
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
  _Tab('Поцелуи', Icons.favorite_border_rounded, Icons.favorite_rounded),
  _Tab('Документы', Icons.folder_outlined, Icons.folder_rounded),
  _Tab('Ещё', Icons.grid_view_rounded, Icons.grid_view_rounded),
];

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  // Скрытые вкладки не перерисовываются при каждом обновлении данных:
  // для них хранится последняя собранная версия. Это сильно разгружает телефон.
  final Map<int, Widget> _cache = {};

  static const _chatTab = 4;
  static const _kissTab = 5;

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
      case _kissTab:
        return KissPage(store: s, active: active);
      case 6:
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
    final unreadChat = _tab == _chatTab ? 0 : s.unreadChat;
    final unreadKiss = _tab == _kissTab ? 0 : s.kissUnseen;
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
          child: LayoutBuilder(
            builder: (context, c) {
              // Выбранная вкладка шире и с подписью, остальные компактные значки.
              const selFactor = 2.3;
              final unit = c.maxWidth / (_tabs.length - 1 + selFactor);
              return Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: i == _tab ? unit * selFactor : unit,
                      child: _item(
                        i,
                        i == _chatTab
                            ? unreadChat
                            : (i == _kissTab ? unreadKiss : 0),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _item(int i, int badge) {
    final t = _tabs[i];
    final sel = i == _tab;
    return PressScale(
      key: ValueKey('tab-${t.label}'),
      scale: 0.88,
      onTap: () => _go(i),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: sel ? 46 : 32,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? kAccentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text(badge > 99 ? '99+' : '$badge'),
              child: Icon(
                sel ? t.selectedIcon : t.icon,
                size: 23,
                color: sel ? kAccentDeep : kInkSoft,
              ),
            ),
          ),
          SizedBox(
            height: 16,
            child: sel
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: kAccentDeep,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
