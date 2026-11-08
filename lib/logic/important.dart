import '../util.dart';

/// Ближайшая дата события не раньше [today].
/// Для ежегодных: тот же день и месяц (29 февраля в невисокосный год → 28 февраля).
/// Для разовых: сама дата, если она не в прошлом, иначе null.
DateTime? nextOccurrence(DateTime date, bool yearly, DateTime today) {
  final t = dateOnly(today);
  final d = dateOnly(date);
  if (!yearly) return d.isBefore(t) ? null : d;
  DateTime inYear(int y) {
    final dim = daysInMonth(y, d.month);
    return DateTime(y, d.month, d.day > dim ? dim : d.day);
  }

  var c = inYear(t.year);
  if (c.isBefore(t)) c = inYear(t.year + 1);
  return c;
}

int daysUntil(DateTime target, DateTime today) => DateTime.utc(
  target.year,
  target.month,
  target.day,
).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

/// «сегодня», «завтра», «через 5 дней».
String untilText(int days) {
  if (days == 0) return 'сегодня';
  if (days == 1) return 'завтра';
  return 'через $days ${plural(days, 'день', 'дня', 'дней')}';
}

/// Сколько полных лет прошло к дате [occurrence].
int yearsAt(DateTime original, DateTime occurrence) =>
    occurrence.year - original.year;
