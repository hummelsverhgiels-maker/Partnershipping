import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/data/store.dart';
import 'package:partnershipping/data/transfer.dart';
import 'package:partnershipping/logic/dog.dart';
import 'package:partnershipping/logic/schedule.dart';
import 'package:partnershipping/services/notifier.dart';
import 'package:partnershipping/util.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  AppStore.saveDelay = Duration.zero;

  group('собака: кто дома', () {
    final day = DateTime(2026, 11, 10);
    final sch = Schedule(
      shifts: {
        '2026-11-09': {
          'b': const ShiftInfo('n', '20:00', '08:00'), // ночная накануне
        },
        '2026-11-10': {
          'a': const ShiftInfo('1', '09:00', '21:00'),
          'b': const ShiftInfo('2', '12:00', '18:00'),
        },
      },
    );

    test('занятость: смена с дорогой и хвост ночной смены', () {
      expect(busySpans(sch, 'a', day, commute: 30), [const Span(510, 1290)]);
      expect(busySpans(sch, 'b', day), [
        const Span(0, 480),
        const Span(720, 1080),
      ]);
      // ночная смена режется на полуночи
      expect(busySpans(sch, 'b', DateTime(2026, 11, 9)), [
        const Span(1200, 1440),
      ]);
    });

    test('одна дома: только когда заняты оба', () {
      final alone = longestAlone(sch, 'a', 'b', day, commute: 30);
      expect(alone, const Span(690, 1110)); // 11:30–18:30
      expect(alone!.length, 420);
      // без партнёра — всё время смены
      expect(longestAlone(sch, 'a', null, day)!.length, 12 * 60);
    });

    test('кто может гулять утром и вечером', () {
      final a = busySpans(sch, 'a', day, commute: 30);
      final b = busySpans(sch, 'b', day, commute: 30);
      expect(freeForWalk(a, kSlotMorning.window), true); // до 8:30
      expect(freeForWalk(b, kSlotMorning.window), true); // с 8:30
      expect(freeForWalk(a, kSlotEvening.window), true); // после 21:30
      expect(freeForWalk(b, const Span(12 * 60, 18 * 60)), false);
      expect(whoCanWalk(true, false), WalkWho.me);
      expect(whoCanWalk(false, false), WalkWho.nobody);
    });

    test('склейка и пересечение промежутков', () {
      expect(
        mergeSpans([const Span(0, 10), const Span(5, 20), const Span(30, 40)]),
        [const Span(0, 20), const Span(30, 40)],
      );
      expect(intersectSpans([const Span(0, 100)], [const Span(50, 150)]), [
        const Span(50, 100),
      ]);
    });
  });

  group('собака: сроки', () {
    test('следующая процедура и подписи', () {
      expect(careNext('2026-11-01', 30), DateTime(2026, 12, 1));
      expect(careNext(null, 30), null);
      expect(dueText(0), 'сегодня');
      expect(dueText(1), 'завтра');
      expect(dueText(5), 'через 5 дней');
      expect(dueText(-3), 'просрочено на 3 дня');
    });

    test('запасы и возраст', () {
      expect(supplyLeft('2026-11-01', 30, DateTime(2026, 11, 28)), 3);
      expect(
        dogAge(DateTime(2023, 5, 20), DateTime(2026, 11, 8)),
        '3 года 5 месяцев',
      );
      expect(dogAge(DateTime(2026, 10, 1), DateTime(2026, 11, 8)), '1 месяц');
      expect(dogAge(DateTime(2026, 10, 25), DateTime(2026, 11, 8)), '2 недели');
      expect(dogAge(DateTime(2025, 11, 8), DateTime(2026, 11, 8)), '1 год');
    });

    test('серия прогулок', () {
      final t = DateTime(2026, 11, 8);
      expect(walkStreak({'2026-11-08', '2026-11-07', '2026-11-05'}, t), 2);
      expect(
        walkStreak({'2026-11-07', '2026-11-06'}, t),
        2,
      ); // сегодня ещё не всё
      expect(walkStreak({}, t), 0);
    });
  });

  test('собака: отметки, план, здоровье, запасы, напоминания', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.init();
    await s.startLocal('Саша', 0xFFFBC9A0);
    final me = s.session!.memberId;
    final today = dateOnly(DateTime.now());

    expect(s.dogName, 'Собака');
    s.saveDog({'name': 'Бублик', 'walks': 3});
    expect(s.dogName, 'Бублик');
    expect(s.dogTodayItems.where((i) => i.walk).length, 3);

    s.toggleDogDone('walk_m');
    expect(s.dogDoneOf(today, 'walk_m')!.s('by'), me);
    expect(s.dogWalksByMember()[me], 1);
    s.toggleDogDone('walk_m');
    expect(s.dogDoneOf(today, 'walk_m'), null);

    for (final i in s.dogTodayItems.where((i) => i.walk)) {
      s.toggleDogDone(i.id);
    }
    expect(walkStreak(s.dogDaysAllWalked, today), 1);

    s.setDogPlan(today, 'e', me);
    expect(s.dogPlanOf(today, 'e'), me);
    s.setDogPlan(today, 'e', null);
    expect(s.dogPlanOf(today, 'e'), null);

    final care = s.upsert('dogcare', {
      'title': 'Клещи',
      'emoji': '🕷️',
      'every': 30,
      'last': ymd(addDays(today, -29)),
    });
    expect(s.dogCareDue().length, 1);
    s.markCareDone(care);
    expect(s.dogCare.single.s('last'), ymd(today));
    expect(s.dogCareDue(), isEmpty);

    final sup = s.upsert('dogsupply', {
      'title': 'Корм',
      'emoji': '🥣',
      'lasts': 10,
      'bought': ymd(addDays(today, -8)),
    });
    expect(s.dogSuppliesLow().length, 1);
    expect(s.supplyToShopping(sup), true);
    expect(s.supplyToShopping(sup), false); // второй раз не дублируем
    expect(s.shopping.where((x) => x.s('title') == '🥣 Корм').length, 1);
    s.markSupplyBought(s.dogSupplies.single);
    expect(s.dogSuppliesLow(), isEmpty);

    s.addDogWeight(12.5, today);
    s.addDogWeight(12.8, today); // тот же день — перезапись
    expect(s.dogWeights.length, 1);
    expect(s.dogWeightNow, 12.8);

    // напоминания: вечерняя прогулка сегодня уже отмечена, клещи — через 30 дней
    final notes = planNotes(
      s,
      DateTime(today.year, today.month, today.day, 12),
    );
    expect(notes.where((n) => n.id == 2000), isEmpty);
    expect(notes.where((n) => n.id == 2001).length, 1);
    expect(notes.any((n) => n.title.contains('Клещи')), true);
    expect(notes.any((n) => n.title.contains('Корм')), true);
    await s.setFlag('notif_dog', false);
    expect(planNotes(s, DateTime.now()).where((n) => n.dog), isEmpty);
  });

  test('передача частями: имена частей и разбор пути', () {
    expect(Transfer.partName('p/a.jpg', 3), 'p/a.jpg.p0003');
    expect(Transfer.parseChunked('chunks:12:p/a.jpg'), (12, 'p/a.jpg'));
    expect(Transfer.parseChunked('p/a.jpg'), null);
    expect(Transfer.allObjectNames('chunks:2:p/a.jpg'), [
      'p/a.jpg.p0000',
      'p/a.jpg.p0001',
    ]);
    expect(Transfer.allObjectNames('p/a.jpg'), ['p/a.jpg']);
  });
}
