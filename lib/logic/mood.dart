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
