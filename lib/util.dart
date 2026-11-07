import 'dart:math';

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Прибавить дни, не ломаясь на переходе на летнее/зимнее время.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

final _rnd = Random.secure();

/// Случайный идентификатор (UUID v4).
String newId() {
  final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// Склонение: plural(2, 'день', 'дня', 'дней') -> 'дня'
String plural(int n, String one, String few, String many) {
  final m100 = n % 100;
  final m10 = n % 10;
  if (m100 >= 11 && m100 <= 14) return many;
  if (m10 == 1) return one;
  if (m10 >= 2 && m10 <= 4) return few;
  return many;
}

/// "09:00" -> минуты от начала суток.
int minutesOf(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String fmtHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// "09:00","21:00" -> "9–21"; "09:30","18:15" -> "9:30–18:15"
String compactTime(String start, String end) {
  String one(String s) {
    final p = s.split(':');
    final h = int.parse(p[0]);
    return p[1] == '00' ? '$h' : '$h:${p[1]}';
  }

  return '${one(start)}–${one(end)}';
}
