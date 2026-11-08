import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
