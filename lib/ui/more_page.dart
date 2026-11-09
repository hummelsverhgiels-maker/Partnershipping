import 'package:flutter/material.dart';

import '../data/store.dart';
import 'budget_page.dart';
import 'common.dart';
import 'docs_page.dart';
import 'backup_page.dart';
import 'dog_extras.dart';
import 'together_pages.dart';
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
          const SectionTitle('🐶 ОЛИВКА'),
          item(
            '🛌',
            'Поза дня',
            'Как спит Оливка, и лучшая поза месяца',
            DogPosesPage(store: store),
          ),
          item(
            '🎬',
            'Видео-альбом',
            'Смешные и милые видео Оливки',
            DogVideosPage(store: store),
          ),
          item(
            '📒',
            'Заметки об Оливке',
            'Команды, любимое, чего боится',
            DogNotesPage(store: store),
          ),
          const SectionTitle('ВМЕСТЕ'),
          item(
            '🫙',
            'Банка благодарностей',
            'За что вы благодарны друг другу',
            GratitudePage(store: store),
          ),
          item(
            '🎲',
            'Идеи для свиданий',
            'Подскажем, чем заняться вдвоём',
            DateIdeasPage(store: store),
          ),
          item(
            '🎁',
            'Дни рождения',
            'Друзья и родные, идеи подарков',
            BirthdaysPage(store: store),
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
          item(
            '💾',
            'Резервная копия',
            'Сохранить все данные файлом и восстановить',
            BackupPage(store: store),
          ),
        ],
      ),
    );
  }
}
