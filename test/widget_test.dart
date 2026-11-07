import 'package:flutter_test/flutter_test.dart';
import 'package:partnershipping/main.dart';

void main() {
  testWidgets('Главный экран открывается и кнопка считает нажатия',
      (tester) async {
    await tester.pumpWidget(const PartnershippingApp());
    expect(find.text('Мы вдвоём'), findsOneWidget);
    await tester.tap(find.text('Проверка: нажато 0'));
    await tester.pump();
    expect(find.text('Проверка: нажато 1'), findsOneWidget);
  });
}
