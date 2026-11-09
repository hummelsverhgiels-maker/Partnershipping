import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/data/store.dart';
import 'package:partnershipping/data/transfer.dart';
import 'package:partnershipping/logic/together.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  AppStore.saveDelay = Duration.zero;

  test('передача частями: имена частей и разбор пути', () {
    expect(Transfer.partName('p/a.jpg', 3), 'p/a.jpg.p0003');
    expect(Transfer.parseChunked('chunks:12:p/a.jpg'), (12, 'p/a.jpg'));
    expect(Transfer.parseChunked('p/a.jpg'), null);
    expect(Transfer.allObjectNames('chunks:2:p/a.jpg'), [
      'p/a.jpg.p0000',
      'p/a.jpg.p0001',
    ]);
    expect(Transfer.allObjectNames('p/a.jpg'), ['p/a.jpg']);
  });

  test('мы вместе: дни, текст и ближайшая круглая дата', () {
    final since = DateTime(2025, 8, 20);
    final today = DateTime(2026, 11, 9);
    expect(daysTogether(since, today), 446);
    expect(togetherText(since, today), '1 год 2 месяца 20 дней');
    final m = nextMilestone(since, today)!;
    expect(m.$1, DateTime(2027, 1, 2)); // 500 дней
    expect(m.$2, '500 дней вместе');
    expect(nextMilestone(DateTime(2026, 11, 9), today)!.$2, '100 дней вместе');
    expect(kDateIdeas.length, greaterThan(10));
  });

  test('резервная копия: выгрузка и восстановление', () async {
    SharedPreferences.setMockInitialValues({});
    final a = AppStore();
    await a.init();
    await a.startLocal('Саша', 0xFFFBC9A0);
    a.setTogetherSince('2025-08-20');
    expect(a.togetherSince, '2025-08-20');
    a.upsert('thanks', {'title': 'ужин', 'ts': 1});
    a.upsert('person', {'name': 'Мама', 'date': '1970-03-08', 'ts': 2});
    a.upsert('dognote', {'cat': 'cmd', 'title': 'Дай лапу', 'ts': 3});
    final text = a.exportBackup();

    SharedPreferences.setMockInitialValues({});
    final b = AppStore();
    await b.init();
    await b.startLocal('Варя', 0xFFA0C4FB);
    expect(b.importBackup(text), greaterThanOrEqualTo(4));
    expect(b.togetherSince, '2025-08-20');
    expect(b.kindList('thanks').single.s('title'), 'ужин');
    expect(b.kindList('person').single.s('name'), 'Мама');
    expect(b.importBackup(text), 0); // повторно ничего нового
    expect(() => b.importBackup('{"app":"x"}'), throwsA(isA<String>()));
  });

  test('календарь: дни рождения и годовщины видны на своих днях', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.init();
    await s.startLocal('Саша', 0xFFFBC9A0);
    s.upsert('person', {'name': 'Мама', 'date': '1970-03-08', 'ts': 1});
    s.upsert('important', {
      'title': 'Отпуск',
      'date': '2026-07-01',
      'yearly': true,
      'emoji': '✈️',
    });
    s.setTogetherSince('2025-08-20');
    final b = s.importantOn(DateTime(2027, 3, 8)).single;
    expect(b.s('title'), 'День рождения: Мама (57)');
    expect(b.s('emoji'), '🎂');
    expect(
      s.importantOn(DateTime(2026, 8, 20)).single.s('title'),
      '1 год вместе!',
    );
    expect(
      s.importantOn(DateTime(2025, 11, 28)).single.s('title'),
      '100 дней вместе!',
    );
    expect(s.importantOn(DateTime(2027, 7, 1)).single.s('emoji'), '✈️');
    expect(s.importantOn(DateTime(2027, 7, 2)), isEmpty);
  });
}
