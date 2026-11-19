/// Настроение от 0 до 100: десять ступеней со смайликом и подписью.
const _steps = <(String, String)>[
  ('😭', 'Ужасно'),
  ('😢', 'Совсем грустно'),
  ('😞', 'Грустно'),
  ('😕', 'Не очень'),
  ('😐', 'Так себе'),
  ('🙂', 'Нормально'),
  ('😊', 'Неплохо'),
  ('😄', 'Хорошо'),
  ('😁', 'Отлично!'),
  ('🤩', 'Прекрасно!'),
];

/// Номер ступени 0..9.
int moodStep(int v) => (v ~/ 10).clamp(0, 9);

String moodEmoji(int v) => _steps[moodStep(v)].$1;

String moodLabel(int v) => _steps[moodStep(v)].$2;

/// Дополнительное состояние к настроению (выбирается кнопкой «+»).
class MoodTag {
  final String id;
  final String label;
  final String emoji;
  const MoodTag(this.id, this.label, this.emoji);
}

/// Группа состояний в окне выбора.
class MoodGroup {
  final String title;
  final List<MoodTag> tags;
  const MoodGroup(this.title, this.tags);
}

const kMoodGroups = <MoodGroup>[
  MoodGroup('Настроение', [
    MoodTag('cheerful', 'Весело', '😆'),
    MoodTag('happy', 'Счастлив(а)', '😊'),
    MoodTag('loving', 'Влюблён(а)', '🥰'),
    MoodTag('excited', 'В предвкушении', '🤩'),
    MoodTag('relaxed', 'Спокойно', '😌'),
    MoodTag('proud', 'Горжусь собой', '😎'),
    MoodTag('inspired', 'Вдохновлён(а)', '✨'),
    MoodTag('grateful', 'Благодарен(на)', '🙏'),
    MoodTag('playful', 'Хочу дурачиться', '😜'),
    MoodTag('newyear', 'Новогоднее настроение', '🎄'),
    MoodTag('sad', 'Грустно', '😢'),
    MoodTag('lonely', 'Одиноко', '😔'),
    MoodTag('bored', 'Скучно', '😒'),
    MoodTag('miss', 'Скучаю по тебе', '🥺'),
    MoodTag('nostalgic', 'Ностальгия', '🥹'),
    MoodTag('anxious', 'Тревожно', '😰'),
    MoodTag('stressed', 'Стресс', '😫'),
    MoodTag('angry', 'Злюсь', '😠'),
    MoodTag('offended', 'Обижен(а)', '😤'),
    MoodTag('embarrassed', 'Смущён(а)', '😳'),
    MoodTag('confused', 'Запутался(лась)', '🤔'),
  ]),
  MoodGroup('Самочувствие', [
    MoodTag('hungry', 'Голодно', '🍔'),
    MoodTag('fed', 'Наелся(лась)', '😋'),
    MoodTag('thirsty', 'Хочу пить', '🥤'),
    MoodTag('tired', 'Устал(а)', '🥱'),
    MoodTag('sleepy', 'Хочу спать', '😴'),
    MoodTag('energetic', 'Полон(на) сил', '⚡'),
    MoodTag('sick', 'Болею', '🤒'),
    MoodTag('headache', 'Болит голова', '🤕'),
    MoodTag('nausea', 'Тошнит', '🤢'),
    MoodTag('sore', 'Болят мышцы', '💪'),
    MoodTag('cold', 'Замёрз(ла)', '🥶'),
    MoodTag('hot', 'Жарко', '🥵'),
  ]),
  MoodGroup('Хочу', [
    MoodTag('hug', 'Хочу обнимашек', '🤗'),
    MoodTag('kiss', 'Хочу поцелуйчик', '💋'),
    MoodTag('call', 'Позвони мне', '📞'),
    MoodTag('chat', 'Хочу поболтать', '💬'),
    MoodTag('alone', 'Хочу побыть одной(ному)', '🧘'),
    MoodTag('coffee', 'Хочу кофе', '☕'),
    MoodTag('tea', 'Хочу чай', '🍵'),
    MoodTag('sweets', 'Хочу сладкого', '🍰'),
    MoodTag('pizza', 'Хочу пиццу', '🍕'),
    MoodTag('sushi', 'Хочу суши', '🍣'),
    MoodTag('movie', 'Хочу кино', '🍿'),
    MoodTag('walk', 'Хочу гулять', '🚶'),
    MoodTag('music', 'Хочу музыку', '🎧'),
    MoodTag('play', 'Хочу поиграть', '🎮'),
    MoodTag('shopping', 'Хочу по магазинам', '🛍️'),
    MoodTag('bath', 'Хочу ванну', '🛁'),
    MoodTag('adventure', 'Хочу приключений', '🎢'),
    MoodTag('home', 'Хочу домой', '🏠'),
    MoodTag('trip', 'Хочу в отпуск', '✈️'),
  ]),
  MoodGroup('Чем занят(а)', [
    MoodTag('busy', 'Занят(а)', '💼'),
    MoodTag('working', 'Работаю', '👩‍💻'),
    MoodTag('study', 'Учусь', '📚'),
    MoodTag('driving', 'В дороге', '🚗'),
    MoodTag('cooking', 'Готовлю', '🍳'),
    MoodTag('cleaning', 'Убираюсь', '🧹'),
    MoodTag('gym', 'В зале', '🏋️'),
    MoodTag('shop', 'В магазине', '🛒'),
    MoodTag('resting', 'Отдыхаю', '🛌'),
    MoodTag('watching', 'Смотрю кино', '📺'),
    MoodTag('reading', 'Читаю', '📖'),
    MoodTag('outside', 'На улице', '🌳'),
    MoodTag('withdog', 'С Оливкой', '🐶'),
  ]),
];

final List<MoodTag> kMoodTags = [for (final g in kMoodGroups) ...g.tags];

/// Собственное состояние хранится как «c:смайлик|текст».
const _customPrefix = 'c:';

String customMoodId(String emoji, String label) =>
    '$_customPrefix$emoji|$label';

bool isCustomMood(String id) => id.startsWith(_customPrefix);

/// Из текста «🍕 Хочу пиццу» получает смайлик и подпись (без смайлика — ✨).
(String, String) parseCustomMood(String text) {
  final t = text.trim();
  if (t.isEmpty) return ('✨', '');
  final first = t.runes.first;
  final isEmoji =
      first >= 0x1F000 ||
      (first >= 0x2600 && first <= 0x27BF) ||
      (first >= 0x2B00 && first <= 0x2BFF);
  if (!isEmoji) return ('✨', t);
  // смайлик может состоять из нескольких символов: берём всё до первого пробела
  final i = t.indexOf(' ');
  if (i < 0) return (t, '');
  return (t.substring(0, i), t.substring(i + 1).trim());
}

MoodTag? moodTagById(String id) {
  if (isCustomMood(id)) {
    final body = id.substring(_customPrefix.length);
    final i = body.indexOf('|');
    if (i < 0) return MoodTag(id, body, '✨');
    return MoodTag(id, body.substring(i + 1), body.substring(0, i));
  }
  for (final t in kMoodTags) {
    if (t.id == id) return t;
  }
  return null;
}
