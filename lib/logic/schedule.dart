import '../util.dart';

class ShiftInfo {
  final String id;
  final String start; // "HH:mm"
  final String end; // "HH:mm"
  const ShiftInfo(this.id, this.start, this.end);

  /// Ночная смена: заканчивается на следующий день.
  bool get overnight => minutesOf(end) <= minutesOf(start);

  String get label => '$start–$end';
}

class PayRule {
  final String id;
  final String memberId;
  final int day; // 1..31
  final String label;
  const PayRule(this.id, this.memberId, this.day, this.label);
}

class PayDate {
  final String id;
  final String memberId;
  final String date; // yyyy-MM-dd
  final String label;
  const PayDate(this.id, this.memberId, this.date, this.label);
}

class PayItem {
  final String memberId;
  final String label;
  final DateTime date; // когда фактически выплата
  final DateTime nominal; // когда должна быть по правилу
  const PayItem(this.memberId, this.label, this.date, this.nominal);
  bool get shifted => date != nominal;
}

class OffInfo {
  final DateTime start;
  final int streak;
  const OffInfo(this.start, this.streak);
}

class Schedule {
  /// дата -> человек -> смена
  final Map<String, Map<String, ShiftInfo>> shifts;

  /// пары "человек|дата", явно отмеченные как выходной
  final Set<String> offMarks;
  final List<PayRule> rules;
  final List<PayDate> payDates;

  /// человек -> сдвигать ли выплату с выходного на предыдущий рабочий день
  final Map<String, bool> shiftPay;

  /// «человек|yyyy-MM»: в этом месяце у человека есть смены или отметки «выходной»
  final Set<String> dataMonths;

  const Schedule({
    this.shifts = const {},
    this.offMarks = const {},
    this.rules = const [],
    this.payDates = const [],
    this.shiftPay = const {},
    this.dataMonths = const {},
  });

  static String monthKey(String memberId, DateTime d) =>
      '$memberId|${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Общий выходной: свободны оба, и у обоих на этот месяц график уже заполнен.
  bool isCommonOff(String a, String b, DateTime d) =>
      isOff(a, d) &&
      isOff(b, d) &&
      dataMonths.contains(monthKey(a, d)) &&
      dataMonths.contains(monthKey(b, d));

  ShiftInfo? shiftOf(String memberId, DateTime d) => shifts[ymd(d)]?[memberId];

  bool hasShift(String memberId, DateTime d) => shiftOf(memberId, d) != null;

  bool explicitOff(String memberId, DateTime d) =>
      offMarks.contains('$memberId|${ymd(d)}');

  /// День без смены считается выходным.
  bool isOff(String memberId, DateTime d) => !hasShift(memberId, d);

  DateTime _effective(String memberId, DateTime nominal) {
    if (!(shiftPay[memberId] ?? false)) return nominal;
    if (!isOff(memberId, nominal)) return nominal;
    for (var i = 1; i <= 14; i++) {
      final d = addDays(nominal, -i);
      if (!isOff(memberId, d)) return d;
    }
    return nominal;
  }

  /// Все выплаты, которые фактически приходятся на период [from, to].
  List<PayItem> paymentsInRange(
    DateTime from,
    DateTime to, {
    String? memberId,
  }) {
    from = dateOnly(from);
    to = dateOnly(to);
    final out = <PayItem>[];
    // Сдвиг идёт только назад (до 14 дней), поэтому смотрим ещё месяц вперёд.
    var y = from.year;
    var m = from.month;
    final last = DateTime(to.year, to.month + 2, 1);
    while (!DateTime(y, m, 1).isAfter(last)) {
      for (final r in rules) {
        if (memberId != null && r.memberId != memberId) continue;
        final day = r.day.clamp(1, daysInMonth(y, m));
        final nominal = DateTime(y, m, day);
        final eff = _effective(r.memberId, nominal);
        if (!eff.isBefore(from) && !eff.isAfter(to)) {
          out.add(PayItem(r.memberId, r.label, eff, nominal));
        }
      }
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    for (final p in payDates) {
      if (memberId != null && p.memberId != memberId) continue;
      final d = parseYmd(p.date);
      if (!d.isBefore(from) && !d.isAfter(to)) {
        out.add(PayItem(p.memberId, p.label, d, d));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }
}

/// Ближайший выходной начиная с [from] (включая сегодняшний день)
/// и сколько выходных идёт подряд.
OffInfo? nextOff(
  DateTime from,
  bool Function(DateTime) isOff, {
  int horizon = 60,
}) {
  from = dateOnly(from);
  for (var i = 0; i < horizon; i++) {
    final d = addDays(from, i);
    if (isOff(d)) {
      var n = 1;
      while (i + n < horizon + 60 && isOff(addDays(d, n))) {
        n++;
      }
      return OffInfo(d, n);
    }
  }
  return null;
}

const _weekdaysIn = [
  'понедельник',
  'вторник',
  'среду',
  'четверг',
  'пятницу',
  'субботу',
  'воскресенье',
];

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

String dayWord(DateTime today, DateTime d) {
  final diff = dateOnly(d).difference(dateOnly(today)).inDays;
  if (diff == 0) return 'сегодня';
  if (diff == 1) return 'завтра';
  if (diff > 1 && diff < 7) {
    final wd = _weekdaysIn[d.weekday - 1];
    return (wd == 'вторник' ? 'во ' : 'в ') + wd;
  }
  return '${d.day} ${_months[d.month - 1]}';
}

/// Например: "Выходной в пятницу, 2 дня подряд".
String offSentence(DateTime today, OffInfo? info) {
  if (info == null) return 'выходных в ближайшие 2 месяца нет';
  if (info.streak >= 30) return 'график ещё не заполнен';
  final base = 'Выходной ${dayWord(today, info.start)}';
  if (info.streak <= 1) return base;
  return '$base, ${info.streak} ${plural(info.streak, 'день', 'дня', 'дней')} подряд';
}
