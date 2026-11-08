import '../util.dart';

/// Шаблон графика: «N рабочих, M выходных» по кругу или «будни/выходные» (5/2).
class SchedulePattern {
  final String label;
  final int work;
  final int off;
  final bool weekdays; // true: рабочие дни Пн–Пт, выходные Сб–Вс
  const SchedulePattern(
    this.label,
    this.work,
    this.off, {
    this.weekdays = false,
  });

  static const presets = <SchedulePattern>[
    SchedulePattern('2/2', 2, 2),
    SchedulePattern('3/3', 3, 3),
    SchedulePattern('1/3', 1, 3),
    SchedulePattern('1/2', 1, 2),
    SchedulePattern('5/2 по будням', 5, 2, weekdays: true),
  ];

  String get title => weekdays
      ? 'Пн–Пт работа, Сб–Вс выходные'
      : '$work ${plural(work, 'рабочий', 'рабочих', 'рабочих')} / $off '
            '${plural(off, 'выходной', 'выходных', 'выходных')}';
}

class PatternResult {
  final List<DateTime> work;
  final List<DateTime> off;
  const PatternResult(this.work, this.off);
}

/// Раскладывает шаблон на [days] дней, начиная с [start].
/// Для цикла первый день [start] всегда рабочий.
PatternResult generatePattern({
  required DateTime start,
  required int days,
  required SchedulePattern pattern,
}) {
  final work = <DateTime>[];
  final off = <DateTime>[];
  final s0 = dateOnly(start);
  final cycle = pattern.work + pattern.off;
  for (var i = 0; i < days; i++) {
    final d = addDays(s0, i);
    final isWork = pattern.weekdays
        ? d.weekday <= 5
        : (cycle > 0 && i % cycle < pattern.work);
    (isWork ? work : off).add(d);
  }
  return PatternResult(work, off);
}
