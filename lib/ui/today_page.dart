import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/important.dart';
import '../logic/stats.dart';
import '../models.dart';
import '../util.dart';
import 'avatar.dart';
import 'common.dart';
import 'day_page.dart';
import 'earnings_page.dart';
import 'important_page.dart';
import 'mood_card.dart';
import 'sheets.dart';
import 'together_pages.dart';
import 'theme.dart';

/// Вкладка «Сегодня»: всё важное на сегодня и ближайшие дни.
class TodayPage extends StatelessWidget {
  final AppStore store;
  final ValueChanged<int> onOpenTab;
  const TodayPage({super.key, required this.store, required this.onOpenTab});

  String _greet() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  void _openDay(BuildContext context, DateTime d) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DayPage(store: store, date: d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    final today = dateOnly(DateTime.now());
    final me = s.me;
    final partner = s.partner;
    final sch = s.schedule;

    // выплата
    String payTitle = 'Выплат нет';
    String paySub = 'Добавьте в «Ещё → Настройки»';
    if (me != null) {
      final pays = sch.paymentsInRange(
        today,
        addDays(today, 62),
        memberId: me.id,
      );
      if (pays.isNotEmpty) {
        final p = pays.first;
        payTitle = '${p.label} ${untilText(daysUntil(p.date, today))}';
        paySub =
            '${p.date.day}.${p.date.month.toString().padLeft(2, '0')}'
            '${p.shifted ? ' · перенесено' : ''}';
      }
    }

    // общий выходной
    String comTitle = 'Нет данных';
    String comSub = partner == null
        ? 'Партнёр не подключён'
        : 'Заполните график';
    if (me != null && partner != null) {
      for (var i = 0; i < 90; i++) {
        final d = addDays(today, i);
        if (sch.isCommonOff(me.id, partner.id, d)) {
          comTitle = i == 0 ? 'Сегодня вместе' : untilText(i);
          comSub = '${d.day}.${d.month.toString().padLeft(2, '0')}';
          break;
        }
      }
    }

    // дела
    final open = s.todos.where((t) => !t.b('done')).toList();
    final todayKey = ymd(today);
    final todaysTodos = open.where((t) => t.s('date') == todayKey).toList();
    final overdue = open
        .where(
          (t) => t.s('date') != null && t.s('date')!.compareTo(todayKey) < 0,
        )
        .length;

    // важные даты
    final upcoming = <(Rec, DateTime)>[];
    for (final r in s.importantDates) {
      final ds = r.s('date');
      if (ds == null) continue;
      final n = nextOccurrence(parseYmd(ds), r.b('yearly'), today);
      if (n != null && daysUntil(n, today) <= 90) upcoming.add((r, n));
    }
    upcoming.sort((a, b) => a.$2.compareTo(b.$2));

    // месяц
    PeriodStats? month;
    double rate = 0;
    if (me != null) {
      rate = s.hourRateFor(me.id);
      month = monthStats(sch, me.id, today.year, today.month, rate);
    }

    final unread = s.unreadChat;
    final scheduleEmpty = sch.shifts.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (me != null) ...[
              Avatar(store: s, memberId: me.id, size: 36),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                '${_greet()}${me != null ? ', ${me.name}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            longDate(today),
            style: TextStyle(color: kInkSoft, fontWeight: FontWeight.w600),
          ),
          if (unread > 0) ...[
            const SizedBox(height: 12),
            SoftCard(
              color: kAccentSoft,
              onTap: () => onOpenTab(4),
              child: Row(
                children: [
                  const Text('💬', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$unread ${plural(unread, 'новое сообщение', 'новых сообщения', 'новых сообщений')}'
                      '${partner != null ? ' от ${partner.name}' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ],
          const SectionTitle('СЕГОДНЯ'),
          _dayCard(context, today),
          const SizedBox(height: 10),
          Text(
            'Завтра',
            style: TextStyle(
              color: kInkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          _dayCard(context, addDays(today, 1), compact: true),
          if (scheduleEmpty) ...[
            const SizedBox(height: 10),
            SoftCard(
              color: kWarnBg,
              child: Text(
                'График пока пуст. Откройте «Календарь» и нажмите ✨, чтобы заполнить его по шаблону (2/2, 3/3 и т. д.).',
                style: TextStyle(color: kInk, height: 1.35),
              ),
            ),
          ],
          const SectionTitle('МЫ ВМЕСТЕ'),
          TogetherCard(store: s),
          const SectionTitle('НАСТРОЕНИЕ'),
          MoodCard(store: s),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _tile('💰', 'Выплата', payTitle, paySub)),
              const SizedBox(width: 10),
              Expanded(child: _tile('💞', 'Общий выходной', comTitle, comSub)),
            ],
          ),
          if (month != null) ...[
            const SectionTitle('ЭТОТ МЕСЯЦ'),
            SoftCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => EarningsPage(store: s)),
              ),
              child: Row(
                children: [
                  _stat('${month.shifts}', 'смен'),
                  _stat(fmtHours(month.hours), 'часов'),
                  _stat(rate > 0 ? fmtMoney(month.earnings) : '—', 'доход'),
                ],
              ),
            ),
          ],
          SectionTitle(
            'ДЕЛА НА СЕГОДНЯ',
            trailing: TextButton(
              onPressed: () => onOpenTab(2),
              child: const Text('Все'),
            ),
          ),
          if (todaysTodos.isEmpty && overdue == 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'На сегодня дел нет 🎉',
                style: TextStyle(color: kInkSoft),
              ),
            ),
          if (overdue > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                color: kErrBg,
                onTap: () => onOpenTab(2),
                child: Text(
                  'Просрочено дел: $overdue',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          for (final t in todaysTodos.take(5)) ...[
            TodoTile(store: s, todo: t),
            const SizedBox(height: 8),
          ],
          if (upcoming.isNotEmpty) ...[
            SectionTitle(
              'БЛИЖАЙШИЕ ДАТЫ',
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ImportantPage(store: s),
                  ),
                ),
                child: const Text('Все'),
              ),
            ),
            for (final u in upcoming.take(3)) ...[
              SoftCard(
                child: Row(
                  children: [
                    Text(
                      u.$1.s('emoji') ?? '⭐',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        u.$1.s('title') ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      untilText(daysUntil(u.$2, today)),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kAccentDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: kInkSoft)),
      ],
    ),
  );

  Widget _tile(String emoji, String label, String title, String sub) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: kInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 12.5, color: kInkSoft)),
        ],
      ),
    );
  }

  Widget _dayCard(BuildContext context, DateTime d, {bool compact = false}) {
    final sch = store.schedule;
    return SoftCard(
      onTap: () => _openDay(context, d),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 10 : 14,
      ),
      child: Column(
        children: [
          for (final m in store.orderedMembers) ...[
            Builder(
              builder: (context) {
                final shift = sch.shiftOf(m.id, d);
                final mine = m.id == store.session?.memberId;
                final text = shift != null
                    ? shift.label + (shift.overnight ? ' 🌙' : '')
                    : 'Выходной';
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: compact ? 22 : 30,
                        decoration: BoxDecoration(
                          color: Color(m.color),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mine ? 'Я' : m.name,
                          style: TextStyle(
                            color: kInkSoft,
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 13 : 14,
                          ),
                        ),
                      ),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: compact ? 15 : 19,
                          fontWeight: FontWeight.w900,
                          color: shift != null ? kInk : kAccentDeep,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
