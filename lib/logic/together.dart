import 'dog.dart' show daysBetween;
import '../util.dart';

/// Сколько целых дней вместе (с учётом дня начала).
int daysTogether(DateTime since, DateTime today) => daysBetween(since, today);

/// «1 год 2 месяца 5 дней».
String togetherText(DateTime since, DateTime today) {
  var y = today.year - since.year;
  var m = today.month - since.month;
  var d = today.day - since.day;
  if (d < 0) {
    m--;
    d += daysInMonth(today.year, today.month == 1 ? 12 : today.month - 1);
  }
  if (m < 0) {
    y--;
    m += 12;
  }
  final parts = <String>[
    if (y > 0) '$y ${plural(y, 'год', 'года', 'лет')}',
    if (m > 0) '$m ${plural(m, 'месяц', 'месяца', 'месяцев')}',
    if (d > 0 || (y == 0 && m == 0)) '$d ${plural(d, 'день', 'дня', 'дней')}',
  ];
  return parts.join(' ');
}

/// Ближайшая «круглая» дата: каждые 100 дней или годовщина.
/// Возвращает (дата, подпись) или null, если даты вместе ещё нет.
(DateTime, String)? nextMilestone(DateTime since, DateTime today) {
  final t = dateOnly(today);
  final n = daysBetween(since, t);
  final nextHundred = (n ~/ 100 + 1) * 100;
  final byDays = (addDays(since, nextHundred), '$nextHundred дней вместе');
  var yr = t.year - since.year;
  DateTime ann(int y) => DateTime(since.year + y, since.month, since.day);
  if (ann(yr).isBefore(t)) yr++;
  if (yr < 1) yr = 1;
  final byYear = (ann(yr), '$yr ${plural(yr, 'год', 'года', 'лет')} вместе');
  return byDays.$1.isBefore(byYear.$1) ? byDays : byYear;
}

/// Идеи для свиданий.
const kDateIdeas = <(String, String)>[
  ('🍿', 'Кино дома с попкорном'),
  ('🌳', 'Прогулка без телефонов'),
  ('🍕', 'Приготовить пиццу вместе'),
  ('🌅', 'Встретить рассвет или закат'),
  ('🎲', 'Вечер настольных игр'),
  ('🧺', 'Пикник в парке'),
  ('☕', 'Новая кофейня, где ещё не были'),
  ('📸', 'Фотосессия друг друга'),
  ('🎳', 'Боулинг или бильярд'),
  ('🛁', 'Домашний спа-вечер'),
  ('🎨', 'Рисовать вместе'),
  ('🚲', 'Покататься на велосипедах'),
  ('🏛️', 'Музей или выставка'),
  ('🍣', 'Попробовать новую кухню'),
  ('🎤', 'Караоке дома'),
  ('⛸️', 'Каток или самокаты'),
  ('🌌', 'Смотреть на звёзды'),
  ('📚', 'Читать друг другу вслух'),
  ('🧩', 'Собрать пазл'),
  ('🎁', 'Подарить друг другу маленький сюрприз'),
  ('🚗', 'Поехать куда глаза глядят'),
  ('🍰', 'Испечь что-нибудь вкусное'),
  ('💌', 'Написать друг другу письма'),
  ('🐾', 'Устроить день собаки: гуляем куда хочет она'),
];
