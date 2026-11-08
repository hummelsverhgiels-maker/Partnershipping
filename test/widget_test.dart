import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:partnershipping/data/store.dart';
import 'package:partnershipping/main.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('Первый запуск показывает экран знакомства', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    final store = AppStore();
    await store.init();
    await tester.pumpWidget(PartnershippingApp(store: store));
    await tester.pump();
    expect(find.text('V&V loving planning'), findsOneWidget);
    expect(find.text('Как вас зовут?'), findsOneWidget);
  });

  testWidgets('Без пары: вход, календарь, смена', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    final store = AppStore();
    await store.init();
    await store.startLocal('Саша', 0xFFFBC9A0);
    await tester.pumpWidget(PartnershippingApp(store: store));
    await tester.pump();
    expect(find.text('Календарь'), findsWidgets);
    final now = DateTime.now();
    store.setShift(
      store.session!.memberId,
      [DateTime(now.year, now.month, 15)],
      '09:00',
      '21:00',
    );
    await tester.pump();
    expect(find.text('9–21'), findsOneWidget);
    expect(
      store.schedule
          .shiftOf(store.session!.memberId, DateTime(now.year, now.month, 15))!
          .end,
      '21:00',
    );
  });
}
