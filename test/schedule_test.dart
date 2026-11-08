import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/logic/schedule.dart';
import 'package:partnershipping/util.dart';

void main() {
  test('ночная смена определяется', () {
    expect(const ShiftInfo('1', '21:00', '07:00').overnight, true);
    expect(const ShiftInfo('1', '09:00', '21:00').overnight, false);
  });

  Schedule sched({bool shiftPay = false}) {
    // Работает 3,4,5 и 8 ноября 2026
    final shifts = <String, Map<String, ShiftInfo>>{};
    for (final d in [3, 4, 5, 8]) {
      shifts['2026-11-${d.toString().padLeft(2, '0')}'] = {
        'a': const ShiftInfo('s', '09:00', '21:00'),
      };
    }
    return Schedule(
      shifts: shifts,
      rules: const [
        PayRule('r1', 'a', 10, 'Аванс'),
        PayRule('r2', 'a', 31, 'Зарплата'),
      ],
      shiftPay: {'a': shiftPay},
    );
  }

  test('выплата без сдвига остаётся в своём дне', () {
    final p = sched().paymentsInRange(
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 30),
    );
    expect(p.map((e) => e.date.day).toList(), [10, 30]); // 31 -> 30 в ноябре
  });

  test('выплата сдвигается на предыдущий рабочий день', () {
    final p = sched(shiftPay: true).paymentsInRange(
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 30),
      memberId: 'a',
    );
    // 10 ноября выходной -> ближайший рабочий назад: 8 ноября
    expect(p.first.date, DateTime(2026, 11, 8));
    expect(p.first.shifted, true);
  });

  test('ближайший выходной и серия подряд', () {
    final s = sched();
    final info = nextOff(DateTime(2026, 11, 3), (d) => s.isOff('a', d));
    expect(info!.start, DateTime(2026, 11, 6));
    expect(info.streak, 2); // 6 и 7 ноября
    expect(
      offSentence(DateTime(2026, 11, 3), info),
      'Выходной в пятницу, 2 дня подряд',
    );
  });

  test('пустой график', () {
    final info = nextOff(DateTime(2026, 11, 3), (d) => true);
    expect(offSentence(DateTime(2026, 11, 3), info), 'график ещё не заполнен');
  });

  test('склонение', () {
    expect(plural(1, 'день', 'дня', 'дней'), 'день');
    expect(plural(3, 'день', 'дня', 'дней'), 'дня');
    expect(plural(12, 'день', 'дня', 'дней'), 'дней');
  });
}
