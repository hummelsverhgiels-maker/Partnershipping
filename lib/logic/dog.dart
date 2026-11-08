import '../util.dart';
import 'schedule.dart';

/// Промежуток в минутах от начала суток (0..1440).
class Span {
  final int from;
  final int to;
  const Span(this.from, this.to);
  int get length => to - from;

  @override
  bool operator ==(Object other) =>
      other is Span && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '${fmtMin(from)}–${fmtMin(to)}';
}

String fmtMin(int m) {
  final c = m.clamp(0, 1440);
  return fmtHm(c ~/ 60 % 24 + (c == 1440 ? 24 : 0), c % 60);
}

/// Пункты ежедневного списка «Собака сегодня».
class DogItem {
  final String id;
  final String emoji;
  final String title;
  final bool walk;
  const DogItem(this.id, this.emoji, this.title, {this.walk = false});
}

const kDogWalkMorning = DogItem(
  'walk_m',
  '🌅',
  'Утренняя прогулка',
  walk: true,
);
const kDogWalkDay = DogItem('walk_d', '☀️', 'Дневная прогулка', walk: true);
const kDogWalkEvening = DogItem(
  'walk_e',
  '🌙',
  'Вечерняя прогулка',
  walk: true,
);
const kDogFeedMorning = DogItem('feed_m', '🥣', 'Завтрак');
const kDogFeedDay = DogItem('feed_d', '🍖', 'Обед');
const kDogFeedEvening = DogItem('feed_e', '🍗', 'Ужин');
const kDogWater = DogItem('water', '💧', 'Свежая вода');

/// Список дел на день: сколько прогулок и кормлений — из паспорта собаки.
List<DogItem> dogItems({int walks = 2, int meals = 2}) => [
  kDogWalkMorning,
  if (walks >= 3) kDogWalkDay,
  kDogWalkEvening,
  kDogFeedMorning,
  if (meals >= 3) kDogFeedDay,
  if (meals >= 2) kDogFeedEvening,
  kDogWater,
];

DogItem? dogItemById(String id) {
  for (final i in [
    kDogWalkMorning,
    kDogWalkDay,
    kDogWalkEvening,
    kDogFeedMorning,
    kDogFeedDay,
    kDogFeedEvening,
    kDogWater,
  ]) {
    if (i.id == id) return i;
  }
  return null;
}

/// Окна для прогулок.
class WalkSlot {
  final String id;
  final String emoji;
  final String title;
  final Span window;
  const WalkSlot(this.id, this.emoji, this.title, this.window);
}

const kSlotMorning = WalkSlot('m', '🌅', 'Утро', Span(6 * 60, 10 * 60));
const kSlotDay = WalkSlot('d', '☀️', 'День', Span(12 * 60, 16 * 60));
const kSlotEvening = WalkSlot('e', '🌙', 'Вечер', Span(18 * 60, 23 * 60));

List<WalkSlot> walkSlots(int walks) => [
  kSlotMorning,
  if (walks >= 3) kSlotDay,
  kSlotEvening,
];

/// Склеить пересекающиеся промежутки.
List<Span> mergeSpans(List<Span> spans) {
  final s = [...spans.where((x) => x.length > 0)]
    ..sort((a, b) => a.from.compareTo(b.from));
  final out = <Span>[];
  for (final x in s) {
    if (out.isNotEmpty && x.from <= out.last.to) {
      final last = out.removeLast();
      out.add(Span(last.from, x.to > last.to ? x.to : last.to));
    } else {
      out.add(x);
    }
  }
  return out;
}

Span? _clip(int from, int to) {
  final f = from < 0 ? 0 : from;
  final t = to > 1440 ? 1440 : to;
  return t > f ? Span(f, t) : null;
}

/// Когда человек не дома в день [day]: его смена (с дорогой туда и обратно)
/// и утренний хвост ночной смены, начавшейся накануне.
List<Span> busySpans(
  Schedule s,
  String memberId,
  DateTime day, {
  int commute = 0,
}) {
  final out = <Span>[];
  final today = s.shiftOf(memberId, day);
  if (today != null) {
    final a = minutesOf(today.start) - commute;
    final b = today.overnight
        ? minutesOf(today.end) + 1440 + commute
        : minutesOf(today.end) + commute;
    final c = _clip(a, b);
    if (c != null) out.add(c);
  }
  final y = s.shiftOf(memberId, addDays(day, -1));
  if (y != null && y.overnight) {
    final c = _clip(0, minutesOf(y.end) + commute);
    if (c != null) out.add(c);
  }
  // смена до полуночи + дорога после неё тоже «залезает» на следующий день
  if (y != null && !y.overnight) {
    final over = minutesOf(y.end) + commute - 1440;
    if (over > 0) out.add(Span(0, over));
  }
  return mergeSpans(out);
}

/// Пересечение двух наборов промежутков (оба заняты одновременно).
List<Span> intersectSpans(List<Span> a, List<Span> b) {
  final out = <Span>[];
  for (final x in a) {
    for (final y in b) {
      final f = x.from > y.from ? x.from : y.from;
      final t = x.to < y.to ? x.to : y.to;
      if (t > f) out.add(Span(f, t));
    }
  }
  return mergeSpans(out);
}

/// Сколько свободных минут у человека внутри окна.
int freeMinutesIn(List<Span> busy, Span window) {
  var taken = 0;
  for (final b in mergeSpans(busy)) {
    final f = b.from > window.from ? b.from : window.from;
    final t = b.to < window.to ? b.to : window.to;
    if (t > f) taken += t - f;
  }
  return window.length - taken;
}

/// Свободен ли человек для прогулки в этом окне (хотя бы 40 минут).
bool freeForWalk(List<Span> busy, Span window) =>
    freeMinutesIn(busy, window) >= 40;

/// Самый длинный промежуток в этот день, когда дома никого нет.
Span? longestAlone(
  Schedule s,
  String a,
  String? b,
  DateTime day, {
  int commute = 0,
}) {
  final ba = busySpans(s, a, day, commute: commute);
  final both = b == null
      ? ba
      : intersectSpans(ba, busySpans(s, b, day, commute: commute));
  Span? best;
  for (final x in both) {
    if (best == null || x.length > best.length) best = x;
  }
  return best;
}

/// Кто гуляет в этом окне.
enum WalkWho { me, partner, both, nobody }

WalkWho whoCanWalk(bool meFree, bool partnerFree) {
  if (meFree && partnerFree) return WalkWho.both;
  if (meFree) return WalkWho.me;
  if (partnerFree) return WalkWho.partner;
  return WalkWho.nobody;
}

// ------------------------------------------------------------- здоровье

class DogCarePreset {
  final String emoji;
  final String title;
  final int every; // дней
  const DogCarePreset(this.emoji, this.title, this.every);
}

const kDogCarePresets = <DogCarePreset>[
  DogCarePreset('💉', 'Прививка (комплексная)', 365),
  DogCarePreset('🦠', 'Прививка от бешенства', 365),
  DogCarePreset('🪱', 'Глистогонка', 90),
  DogCarePreset('🕷️', 'От клещей и блох', 30),
  DogCarePreset('🩺', 'Осмотр у ветеринара', 365),
  DogCarePreset('✂️', 'Груминг / стрижка', 45),
  DogCarePreset('💅', 'Подстричь когти', 21),
  DogCarePreset('🛁', 'Купание', 30),
  DogCarePreset('🦷', 'Почистить зубы', 7),
  DogCarePreset('👂', 'Почистить уши', 14),
];

/// Когда следующий раз (null — ещё ни разу не делали).
DateTime? careNext(String? lastYmd, int every) {
  if (lastYmd == null || lastYmd.isEmpty || every <= 0) return null;
  return addDays(parseYmd(lastYmd), every);
}

int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// «через 5 дней», «сегодня», «просрочено на 3 дня».
String dueText(int days) {
  if (days < 0) {
    final n = -days;
    return 'просрочено на $n ${plural(n, 'день', 'дня', 'дней')}';
  }
  if (days == 0) return 'сегодня';
  if (days == 1) return 'завтра';
  return 'через $days ${plural(days, 'день', 'дня', 'дней')}';
}

// --------------------------------------------------------------- запасы

class DogSupplyPreset {
  final String emoji;
  final String title;
  final int lasts; // примерно дней
  const DogSupplyPreset(this.emoji, this.title, this.lasts);
}

const kDogSupplyPresets = <DogSupplyPreset>[
  DogSupplyPreset('🥣', 'Сухой корм', 30),
  DogSupplyPreset('🥫', 'Влажный корм', 14),
  DogSupplyPreset('🦴', 'Лакомства', 14),
  DogSupplyPreset('🛍️', 'Пакеты для прогулок', 30),
  DogSupplyPreset('💊', 'Таблетки от клещей', 90),
  DogSupplyPreset('🧴', 'Шампунь', 90),
  DogSupplyPreset('🧸', 'Игрушка', 60),
];

/// Сколько дней ещё хватит запаса.
int supplyLeft(String boughtYmd, int lasts, DateTime today) =>
    lasts - daysBetween(parseYmd(boughtYmd), today);

// --------------------------------------------------------------- возраст

/// «3 года 2 месяца», «5 месяцев», «2 недели».
String dogAge(DateTime birth, DateTime today) {
  var months = (today.year - birth.year) * 12 + today.month - birth.month;
  if (today.day < birth.day) months--;
  if (months < 0) return '';
  if (months == 0) {
    final w = daysBetween(birth, today) ~/ 7;
    return w <= 0
        ? 'новорождённый'
        : '$w ${plural(w, 'неделя', 'недели', 'недель')}';
  }
  final y = months ~/ 12;
  final m = months % 12;
  final parts = <String>[
    if (y > 0) '$y ${plural(y, 'год', 'года', 'лет')}',
    if (m > 0) '$m ${plural(m, 'месяц', 'месяца', 'месяцев')}',
  ];
  return parts.join(' ');
}

/// Сколько дней подряд (до сегодня включительно, если сегодня всё сделано,
/// иначе до вчера) все прогулки были отмечены.
int walkStreak(Set<String> daysAllWalked, DateTime today) {
  var d = dateOnly(today);
  if (!daysAllWalked.contains(ymd(d))) d = addDays(d, -1);
  var n = 0;
  while (daysAllWalked.contains(ymd(d))) {
    n++;
    d = addDays(d, -1);
  }
  return n;
}
