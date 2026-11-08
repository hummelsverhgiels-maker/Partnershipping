import 'package:flutter/material.dart';

import '../data/store.dart';
import 'budget_page.dart';
import 'common.dart';
import 'docs_page.dart';
import 'dog_care.dart';
import 'dog_passport.dart';
import 'dog_today.dart';
import 'earnings_page.dart';
import 'important_page.dart';
import 'kiss_page.dart';
import 'settings_page.dart';
import 'theme.dart';

/// Вкладка «Ещё»: поцелуи, документы, собака, заработок, бюджет и настройки.
class MorePage extends StatelessWidget {
  final AppStore store;
  const MorePage({super.key, required this.store});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    Widget item(
      String emoji,
      String title,
      String sub,
      Widget page, {
      int badge = 0,
    }) => Padding(
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
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccentDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            Icon(Icons.chevron_right_rounded, color: kInkSoft),
          ],
        ),
      ),
    );

    final today = DateTime.now();
    final dogLeft = store.dogTodayItems
        .where((i) => store.dogDoneOf(today, i.id) == null)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Ещё')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          item(
            '💋',
            'Поцелуи',
            'Тапайте и отправляйте поцелуйчики',
            KissPage(store: store, active: true),
            badge: store.kissUnseen,
          ),
          item(
            '📁',
            'Документы',
            'Файлы и ссылки, в том числе Google Диск',
            DocsPage(store: store),
          ),
          SectionTitle('${store.dogEmoji} ${store.dogName.toUpperCase()}'),
          item(
            '🦮',
            '${store.dogName} сегодня',
            'Прогулки и кормёжка: кто и во сколько',
            DogTodayPage(store: store),
            badge: dogLeft,
          ),
          item(
            '🗓️',
            'Кто гуляет',
            'План прогулок по сменам на неделю',
            DogWalkPlanPage(store: store),
          ),
          item(
            '💉',
            'Здоровье',
            'Прививки, клещи, глистогонка, вес',
            DogHealthPage(store: store),
            badge: store.dogCareDue().length,
          ),
          item(
            '🥣',
            'Запасы',
            'Корм и всё нужное: когда закончится',
            DogSuppliesPage(store: store),
            badge: store.dogSuppliesLow().length,
          ),
          item(
            '🐕',
            'Паспорт собаки',
            'Кличка, порода, чип, ветеринар, аллергии',
            DogPassportPage(store: store),
          ),
          const SectionTitle('ПАРА И ДЕНЬГИ'),
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
