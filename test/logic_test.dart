import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/logic/important.dart';
import 'package:partnershipping/logic/pattern.dart';
import 'package:partnershipping/logic/schedule.dart';
import 'package:partnershipping/logic/stats.dart';

void main() {
  group('график по шаблону', () {
    test('2/2: рабочие дни идут парами', () {
      final r = generatePattern(
        start: DateTime(2026, 11, 3),
        days: 8,
        pattern: const SchedulePattern('2/2', 2, 2),
      );
      expect(r.work.map((d) => d.day).toList(), [3, 4, 7, 8]);
      expect(r.off.map((d) => d.day).toList(), [5, 6, 9, 10]);
    });

    test('1/3: сутки через трое', () {
      final r = generatePattern(
        start: DateTime(2026, 11, 1),
        days: 9,
        pattern: const SchedulePattern('1/3', 1, 3),
      );
      expect(r.work.map((d) => d.day).toList(), [1, 5, 9]);
    });

    test('5/2 по будням: Сб и Вс выходные', () {
      final r = generatePattern(
        start: DateTime(2026, 11, 2), // понедельник
        days: 7,
        pattern: SchedulePattern.presets.last,
      );
      expect(r.work.length, 5);
      expect(r.off.map((d) => d.weekday).toList(), [6, 7]);
    });

    test('переход через конец месяца и года', () {
      final r = generatePattern(
        start: DateTime(2026, 12, 30),
        days: 4,
        pattern: const SchedulePattern('2/2', 2, 2),
      );
      expect(r.work, [DateTime(2026, 12, 30), DateTime(2026, 12, 31)]);
      expect(r.off, [DateTime(2027, 1, 1), DateTime(2027, 1, 2)]);
    });
  });

  group('часы и заработок', () {
    test('дневная и ночная смена', () {
      expect(shiftHours(const ShiftInfo('a', '09:00', '21:00')), 12);
      expect(shiftHours(const ShiftInfo('a', '21:00', '07:00')), 10);
      expect(shiftHours(const ShiftInfo('a', '08:30', '17:00')), 8.5);
    });

    test('ночные часы (22:00–06:00)', () {
      expect(nightMinutes(const ShiftInfo('a', '09:00', '21:00')), 0);
      expect(nightMinutes(const ShiftInfo('a', '21:00', '07:00')) / 60, 8);
      expect(nightMinutes(const ShiftInfo('a', '20:00', '08:00')) / 60, 8);
      expect(nightMinutes(const ShiftInfo('a', '00:00', '06:00')) / 60, 6);
    });

    test('итоги за месяц', () {
      final sch = Schedule(
        shifts: {
          '2026-11-03': {'a': const ShiftInfo('1', '09:00', '21:00')},
          '2026-11-04': {'a': const ShiftInfo('2', '21:00', '07:00')},
          '2026-12-01': {'a': const ShiftInfo('3', '09:00', '21:00')},
        },
      );
      final st = monthStats(sch, 'a', 2026, 11, 300);
      expect(st.shifts, 2);
      expect(st.hours, 22);
      expect(st.earnings, 6600);
      expect(st.nightHours, 8);
      expect(st.avgHours, 11);
    });

    test('форматирование', () {
      expect(fmtMoney(1234567.5), '1 234 568 ₽');
      expect(fmtMoney(0), '0 ₽');
      expect(fmtHours(7.5), '7 ч 30 мин');
      expect(fmtHours(12), '12 ч');
    });
  });

  group('важные даты', () {
    final today = DateTime(2026, 11, 8);
    test('ежегодная: в этом году ещё впереди', () {
      expect(
        nextOccurrence(DateTime(1995, 12, 5), true, today),
        DateTime(2026, 12, 5),
      );
    });
    test('ежегодная: в этом году уже прошла', () {
      expect(
        nextOccurrence(DateTime(1995, 3, 2), true, today),
        DateTime(2027, 3, 2),
      );
    });
    test('сегодня считается сегодня', () {
      expect(nextOccurrence(DateTime(2000, 11, 8), true, today), today);
      expect(daysUntil(today, today), 0);
    });
    test('29 февраля в невисокосный год', () {
      expect(
        nextOccurrence(DateTime(2020, 2, 29), true, DateTime(2027, 1, 10)),
        DateTime(2027, 2, 28),
      );
    });
    test('разовая: прошлая → null', () {
      expect(nextOccurrence(DateTime(2026, 1, 1), false, today), isNull);
      expect(
        nextOccurrence(DateTime(2026, 12, 1), false, today),
        DateTime(2026, 12, 1),
      );
    });
    test('тексты', () {
      expect(untilText(0), 'сегодня');
      expect(untilText(1), 'завтра');
      expect(untilText(23), 'через 23 дня');
      expect(untilText(25), 'через 25 дней');
      expect(yearsAt(DateTime(2023, 5, 1), DateTime(2026, 5, 1)), 3);
    });
  });

  test('общие выходные: нужен заполненный график у обоих', () {
    final sch = Schedule(
      shifts: {
        '2026-11-03': {'a': const ShiftInfo('1', '09:00', '21:00')},
      },
      dataMonths: {'a|2026-11', 'b|2026-11'},
    );
    expect(
      sch.isCommonOff('a', 'b', DateTime(2026, 11, 3)),
      false,
    ); // a работает
    expect(sch.isCommonOff('a', 'b', DateTime(2026, 11, 4)), true);
    expect(
      sch.isCommonOff('a', 'b', DateTime(2026, 12, 4)),
      false,
    ); // нет данных
  });
}
