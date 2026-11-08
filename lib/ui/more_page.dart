import 'package:flutter/material.dart';

import '../data/store.dart';
import 'budget_page.dart';
import 'common.dart';
import 'earnings_page.dart';
import 'important_page.dart';
import 'settings_page.dart';
import 'theme.dart';

/// Вкладка «Ещё»: заработок, важные даты, бюджет и настройки.
class MorePage extends StatelessWidget {
  final AppStore store;
  const MorePage({super.key, required this.store});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    Widget item(String emoji, String title, String sub, Widget page) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        onTap: () => _open(context, page),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kAccentSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(sub, style: TextStyle(color: kInkSoft, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kInkSoft),
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Ещё')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          item(
            '💰',
            'Заработок',
            'Часы, смены и примерный доход за месяц',
            EarningsPage(store: store),
          ),
          item(
            '🎂',
            'Важные даты',
            'Дни рождения, годовщины, отпуск',
            ImportantPage(store: store),
          ),
          item(
            '🧾',
            'Бюджет',
            'Общие траты и копилки на цели',
            BudgetPage(store: store),
          ),
          item(
            '⚙️',
            'Настройки',
            'Профиль, пара, шаблоны, выплаты, тема',
            SettingsPage(store: store),
          ),
        ],
      ),
    );
  }
}
