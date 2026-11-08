import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  mediaTests();
  test('чат: сообщение появляется и считается прочитанным', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.init();
    await s.startLocal('Саша', 0xFFFBC9A0);
    s.sendMessage('  привет  ');
    s.sendMessage('   ');
    expect(s.messages.length, 1);
    expect(s.messages.first.s('text'), 'привет');
    // свои сообщения не считаются непрочитанными
    expect(s.unreadChat, 0);
  });
}

void mediaTests() {
  test('чат: файл, важное и автор', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppStore();
    await s.init();
    await s.startLocal('Саша', 0xFFFBC9A0);
    s.sendMedia(type: 'image', path: 'p/x.jpg', name: 'x.jpg', size: 10);
    final m = s.messages.single;
    expect(m.s('type'), 'image');
    expect(s.authorOf(m), s.session!.memberId);
    s.toggleImportant(m);
    expect(s.messages.single.b('important'), true);
    s.toggleImportant(s.messages.single);
    expect(s.messages.single.b('important'), false);
  });
}
