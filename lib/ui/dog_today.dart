import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/dog.dart';
import '../logic/important.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'dog_care.dart';
import 'dog_passport.dart';
import 'theme.dart';

/// «Я» или имя партнёра.
String dogWho(AppStore s, String? id) {
  if (id == null) return '—';
  if (id == s.session?.memberId) return 'Я';
  return nameOf(s.memberById(id));
}

String _hm(int? ts) {
  if (ts == null) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(ts);
  return fmtHm(t.hour, t.minute);
}

Widget dogEmojiBox(String emoji, {double size = 46, Color? color}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: color ?? kAccentSoft,
    borderRadius: BorderRadius.circular(size * 0.36),
  ),
  child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
);

/// Предупреждения о собаке на сегодня (запасы, здоровье, одна дома, день рождения).
List<(String, String, bool)> dogWarnings(AppStore s, DateTime today) {
  final out = <(String, String, bool)>[]; // эмодзи, текст, срочно
  for (final r in s.dogSuppliesLow(today: today)) {
    final left = supplyLeft(r.s('bought')!, r.i('lasts') ?? 30, today);
    out.add((
      r.s('emoji') ?? '🥣',
      left <= 0
          ? '${r.s('title')}: закончилось'
          : '${r.s('title')}: хватит на $left ${plural(left, 'день', 'дня', 'дней')}',
      left <= 0,
    ));
  }
  for (final r in s.dogCareDue(today: today)) {
    final n = careNext(r.s('last'), r.i('every') ?? 0)!;
    final d = daysBetween(today, n);
    out.add((r.s('emoji') ?? '💉', '${r.s('title')}: ${dueText(d)}', d < 0));
  }
  final me = s.me;
  if (me != null) {
    final alone = longestAlone(
      s.schedule,
      me.id,
      s.partner?.id,
      today,
      commute: s.dogCommute,
    );
    if (alone != null && alone.length >= s.dogAloneMax * 60) {
      final h = (alone.length / 60).toStringAsFixed(
        alone.length % 60 == 0 ? 0 : 1,
      );
      out.add(('🏠', 'Дома никого $alone (≈$h ч) — это долго', true));
    }
  }
  final b = s.dog?.s('birthday');
  if (b != null && b.isNotEmpty) {
    final next = nextOccurrence(parseYmd(b), true, today);
    if (next != null) {
      final d = daysUntil(next, today);
      if (d <= 14) {
        final y = yearsAt(parseYmd(b), next);
        out.add((
          '🎂',
          '${s.dogName}: день рождения ${untilText(d)}'
              '${y > 0 ? ' — исполнится $y' : ''}',
          false,
        ));
      }
    }
  }
  return out;
}

void _openToday(BuildContext context, AppStore s) => Navigator.push(
  context,
  MaterialPageRoute<void>(builder: (_) => DogTodayPage(store: s)),
);

/// Карточка на вкладке «Сегодня».
class DogTodayCard extends StatelessWidget {
  final AppStore store;
  const DogTodayCard({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final today = dateOnly(DateTime.now());
    final items = s.dogTodayItems;
    final done = items.where((i) => s.dogDoneOf(today, i.id) != null).length;
    final left = items.where((i) => s.dogDoneOf(today, i.id) == null).toList();
    final warns = dogWarnings(s, today);
    return SoftCard(
      key: const ValueKey('dog-today-card'),
      onTap: () => _openToday(context, s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(s.dogEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${s.dogName} сегодня',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$done из ${items.length}',
                style: TextStyle(color: kInkSoft, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: items.isEmpty ? 0 : done / items.length,
              minHeight: 8,
              backgroundColor: kField,
            ),
          ),
          if (left.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in left)
                  ActionChip(
                    avatar: Text(i.emoji),
                    label: Text(i.title),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      s.toggleDogDone(i.id);
                    },
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Всё сделано — хороший день 🐾',
              style: TextStyle(color: kInkSoft),
            ),
          ],
          for (final w in warns.take(3)) ...[
            const SizedBox(height: 6),
            Text(
              '${w.$1} ${w.$2}',
              style: TextStyle(
                color: w.$3 ? const Color(0xFFD9534F) : kInk,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 1) «Собака сегодня»: прогулки и кормёжка — кто и когда отметил.
class DogTodayPage extends StatefulWidget {
  final AppStore store;
  const DogTodayPage({super.key, required this.store});

  @override
  State<DogTodayPage> createState() => _DogTodayPageState();
}

class _DogTodayPageState extends State<DogTodayPage> {
  int _shift = 0; // 0 — сегодня, -1 — вчера

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final day = addDays(today, _shift);
        final items = s.dogTodayItems;
        final streak = walkStreak(s.dogDaysAllWalked, today);
        final byMember = s.dogWalksByMember(today: today);
        final warns = dogWarnings(s, today);
        return Scaffold(
          appBar: AppBar(title: Text('${s.dogEmoji} ${s.dogName} сегодня')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Вчера'),
                    selected: _shift == -1,
                    onSelected: (_) => setState(() => _shift = -1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Сегодня'),
                    selected: _shift == 0,
                    onSelected: (_) => setState(() => _shift = 0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      longDate(day),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      style: TextStyle(color: kInkSoft, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final i in items) ...[
                _itemTile(s, day, i),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 6),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _stat(
                        '🔥 $streak',
                        '${plural(streak, 'день', 'дня', 'дней')} подряд все прогулки',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _stat(
                        [
                          for (final m in s.orderedMembers)
                            '${dogWho(s, m.id)} ${byMember[m.id] ?? 0}',
                        ].join(' · '),
                        'прогулок за 7 дней',
                      ),
                    ),
                  ],
                ),
              ),
              if (warns.isNotEmpty) ...[
                const SectionTitle('ВАЖНО'),
                SoftCard(
                  color: warns.any((w) => w.$3) ? kErrBg : kWarnBg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final w in warns)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '${w.$1} ${w.$2}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SectionTitle('ЕЩЁ ДЛЯ СОБАКИ'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Text('🗓️'),
                    label: const Text('Кто гуляет'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DogWalkPlanPage(store: s),
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Text('💉'),
                    label: const Text('Здоровье'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DogHealthPage(store: s),
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Text('🥣'),
                    label: const Text('Запасы'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DogSuppliesPage(store: s),
                      ),
                    ),
                  ),
                  ActionChip(
                    avatar: const Text('🐕'),
                    label: const Text('Паспорт'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => DogPassportPage(store: s),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String value, String label) => SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: kInkSoft, fontSize: 12.5)),
      ],
    ),
  );

  Widget _itemTile(AppStore s, DateTime day, DogItem i) {
    final r = s.dogDoneOf(day, i.id);
    final done = r != null;
    return SoftCard(
      key: ValueKey('dog-item-${i.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: done ? kAccentSoft : null,
      onTap: () {
        HapticFeedback.lightImpact();
        s.toggleDogDone(i.id, day: day);
      },
      child: Row(
        children: [
          dogEmojiBox(i.emoji, color: done ? kSurface : null),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  done
                      ? '${dogWho(s, r.s('by'))} · ${_hm(r.i('ts'))}'
                      : 'Нажмите, когда сделаете',
                  style: TextStyle(color: kInkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              key: ValueKey(done),
              color: done ? kAccentDeep : kInkSoft,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2) «Кто гуляет»: по сменам из календаря — кто свободен утром и вечером,
/// и сколько собака будет одна.
class DogWalkPlanPage extends StatelessWidget {
  final AppStore store;
  const DogWalkPlanPage({super.key, required this.store});

  Future<void> _pick(BuildContext context, DateTime day, WalkSlot slot) async {
    final s = store;
    final cur = s.dogPlanOf(day, slot.id);
    final r = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${slot.emoji} ${slot.title}, ${longDate(day)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            for (final m in s.orderedMembers)
              ListTile(
                leading: ColorDot(m.color),
                title: Text(
                  m.id == s.session?.memberId ? 'Гуляю я' : 'Гуляет ${m.name}',
                ),
                trailing: cur == m.id ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, m.id),
              ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Как получится (по графику)'),
              trailing: cur == null ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
          ],
        ),
      ),
    );
    if (r == null) return;
    s.setDogPlan(day, slot.id, r.isEmpty ? null : r);
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final me = s.me;
        final partner = s.partner;
        return Scaffold(
          appBar: AppBar(title: const Text('Кто гуляет')),
          body: me == null
              ? const EmptyHint('Сначала войдите в пару')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: [
                    Text(
                      'Считаем по сменам из календаря (плюс ${s.dogCommute} мин '
                      'на дорогу). Нажмите на прогулку, чтобы договориться, кто идёт.',
                      style: TextStyle(color: kInkSoft, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < 7; i++)
                      _dayCard(context, addDays(today, i), i, me, partner),
                  ],
                ),
        );
      },
    );
  }

  Widget _dayCard(
    BuildContext context,
    DateTime day,
    int index,
    Member me,
    Member? partner,
  ) {
    final s = store;
    final sch = s.schedule;
    final c = s.dogCommute;
    final myBusy = busySpans(sch, me.id, day, commute: c);
    final pBusy = partner == null
        ? const <Span>[]
        : busySpans(sch, partner.id, day, commute: c);
    final alone = longestAlone(sch, me.id, partner?.id, day, commute: c);
    final tooLong = alone != null && alone.length >= s.dogAloneMax * 60;
    final title = index == 0
        ? 'Сегодня'
        : (index == 1 ? 'Завтра' : longDate(day));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            for (final slot in walkSlots(s.dogWalks))
              _slotRow(context, day, slot, myBusy, pBusy, me, partner),
            if (alone != null && alone.length >= 60) ...[
              const SizedBox(height: 4),
              Text(
                '${tooLong ? '⚠️' : '🏠'} Дома никого: $alone '
                '(${(alone.length / 60).toStringAsFixed(alone.length % 60 == 0 ? 0 : 1)} ч)',
                style: TextStyle(
                  color: tooLong ? const Color(0xFFD9534F) : kInkSoft,
                  fontWeight: tooLong ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (tooLong)
                Text(
                  'Дольше ${s.dogAloneMax} ч — может, попросить кого-то выгулять днём?',
                  style: TextStyle(color: kInkSoft, fontSize: 12.5),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slotRow(
    BuildContext context,
    DateTime day,
    WalkSlot slot,
    List<Span> myBusy,
    List<Span> pBusy,
    Member me,
    Member? partner,
  ) {
    final s = store;
    final planned = s.dogPlanOf(day, slot.id);
    final who = whoCanWalk(
      freeForWalk(myBusy, slot.window),
      partner != null && freeForWalk(pBusy, slot.window),
    );
    String text;
    Color? color;
    if (planned != null) {
      text =
          '${dogWho(s, planned) == 'Я' ? 'Гуляю я' : 'Гуляет ${dogWho(s, planned)}'} · договорились';
      color = s.memberById(planned) == null
          ? null
          : Color(s.memberById(planned)!.color);
    } else {
      switch (who) {
        case WalkWho.both:
          text = partner == null ? 'Вы свободны' : 'Свободны оба';
        case WalkWho.me:
          text = 'Свободен(на): я';
          color = Color(me.color);
        case WalkWho.partner:
          text = 'Свободен(на): ${partner!.name}';
          color = Color(partner.color);
        case WalkWho.nobody:
          text = '⚠️ Оба заняты — погулять заранее или позже';
      }
    }
    return InkWell(
      key: ValueKey('slot-${ymd(day)}-${slot.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context, day, slot),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(slot.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: Text(
                '${slot.title} ${compactTime(fmtMin(slot.window.from), fmtMin(slot.window.to))}',
                style: TextStyle(color: kInkSoft, fontSize: 13),
              ),
            ),
            if (color != null) ...[
              ColorDot(color.toARGB32()),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: planned != null
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: who == WalkWho.nobody && planned == null
                      ? const Color(0xFFD9534F)
                      : kInk,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: kInkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
