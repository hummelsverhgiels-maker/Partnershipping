/// Настроение от 0 до 100: подпись и смайлик.
String moodEmoji(int v) {
  if (v <= 20) return '😢';
  if (v <= 40) return '😕';
  if (v <= 60) return '😐';
  if (v <= 80) return '🙂';
  return '😄';
}

String moodLabel(int v) {
  if (v <= 20) return 'Совсем грустно';
  if (v <= 40) return 'Не очень';
  if (v <= 60) return 'Нормально';
  if (v <= 80) return 'Хорошо';
  return 'Отлично!';
}

/// Дополнительные состояния к настроению (выбираются кнопкой «+»).
class MoodTag {
  final String id;
  final String label;
  final String emoji;
  const MoodTag(this.id, this.label, this.emoji);
}

const kMoodTags = <MoodTag>[
  MoodTag('hungry', 'Голодно', '🍔'),
  MoodTag('tired', 'Устал(а)', '🥱'),
  MoodTag('cheerful', 'Весело', '😆'),
  MoodTag('bored', 'Скучно', '😒'),
  MoodTag('miss', 'Скучаю по тебе', '🥺'),
  MoodTag('sleepy', 'Хочу спать', '😴'),
  MoodTag('loving', 'Влюблён(а)', '🥰'),
  MoodTag('hug', 'Хочу обнимашек', '🤗'),
  MoodTag('excited', 'В предвкушении', '🤩'),
  MoodTag('relaxed', 'Спокойно', '😌'),
  MoodTag('anxious', 'Тревожно', '😰'),
  MoodTag('angry', 'Злюсь', '😠'),
  MoodTag('sick', 'Болею', '🤒'),
  MoodTag('busy', 'Занят(а)', '💼'),
  MoodTag('cold', 'Замёрз(ла)', '🥶'),
  MoodTag('coffee', 'Хочу кофе', '☕'),
  MoodTag('walk', 'Хочу гулять', '🚶'),
  MoodTag('movie', 'Хочу кино', '🍿'),
];

const kMaxMoodTags = 4;

MoodTag? moodTagById(String id) {
  for (final t in kMoodTags) {
    if (t.id == id) return t;
  }
  return null;
}
