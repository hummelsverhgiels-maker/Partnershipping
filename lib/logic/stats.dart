import '../util.dart';
import 'schedule.dart';

/// Длительность смены в часах (ночные смены считаются верно).
double shiftHours(ShiftInfo s) {
  var d = minutesOf(s.end) - minutesOf(s.start);
  if (d <= 0) d += 24 * 60;
  return d / 60.0;
}

/// Сколько минут смены попадает на ночь (22:00–06:00).
int nightMinutes(ShiftInfo s) {
  final a = minutesOf(s.start);
  var d = minutesOf(s.end) - a;
  if (d <= 0) d += 24 * 60;
  final b = a + d;
  int overlap(int x1, int x2) {
    final lo = a > x1 ? a : x1;
    final hi = b < x2 ? b : x2;
    return hi > lo ? hi - lo : 0;
  }

  // ночные окна на двух сутках: 00–06, 22–30 (то есть до 06 следующего дня), 46–48
  return overlap(0, 6 * 60) +
      overlap(22 * 60, 30 * 60) +
      overlap(46 * 60, 48 * 60);
}

class PeriodStats {
  final int shifts;
  final double hours;
  final double nightHours;
  final double earnings;
  const PeriodStats(this.shifts, this.hours, this.nightHours, this.earnings);

  double get avgHours => shifts == 0 ? 0 : hours / shifts;
}

/// Итоги по сменам человека за период [from, to] включительно
/// (смена считается по дню её начала).
PeriodStats periodStats(
  Schedule sch,
  String memberId,
  DateTime from,
  DateTime to,
  double rate,
) {
  var shifts = 0;
  var hours = 0.0;
  var night = 0.0;
  for (var d = dateOnly(from); !d.isAfter(dateOnly(to)); d = addDays(d, 1)) {
    final s = sch.shiftOf(memberId, d);
    if (s == null) continue;
    shifts++;
    hours += shiftHours(s);
    night += nightMinutes(s) / 60.0;
  }
  return PeriodStats(shifts, hours, night, hours * rate);
}

PeriodStats monthStats(
  Schedule sch,
  String memberId,
  int year,
  int month,
  double rate,
) => periodStats(
  sch,
  memberId,
  DateTime(year, month, 1),
  DateTime(year, month, daysInMonth(year, month)),
  rate,
);

/// Красиво: 1234567.5 -> «1 234 568 ₽».
String fmtMoney(num v) {
  final n = v.round();
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${n < 0 ? '−' : ''}$b ₽';
}

/// Часы: 7.5 -> «7 ч 30 мин», 12 -> «12 ч».
String fmtHours(double h) {
  final total = (h * 60).round();
  final hh = total ~/ 60;
  final mm = total % 60;
  if (mm == 0) return '$hh ч';
  if (hh == 0) return '$mm мин';
  return '$hh ч $mm мин';
}
