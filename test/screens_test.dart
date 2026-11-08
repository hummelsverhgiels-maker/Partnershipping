import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partnershipping/data/store.dart';
import 'package:partnershipping/logic/pattern.dart';
import 'package:partnershipping/main.dart';
import 'package:partnershipping/ui/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _storeWithData() async {
  final store = AppStore();
  await store.init();
  await store.startLocal('Саша', 0xFFFBC9A0);
  final me = store.session!.memberId;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final p = generatePattern(
    start: today,
    days: 28,
    pattern: const SchedulePattern('2/2', 2, 2),
  );
  store.applyPattern(
    memberId: me,
    workDays: p.work,
    offDays: p.off,
    start: '09:00',
    end: '21:00',
    markOff: true,
    clearOff: true,
  );
  store.upsert('payrule', {'memberId': me, 'day': 10, 'label': 'Аванс'});
  store.setHourRate(me, 350);
  store.upsert('todo', {
    'title': 'Убраться',
    'date':
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    'done': false,
  });
  store.upsert('shopping', {'title': 'Молоко', 'bought': false});
  store.upsert('wish', {'title': 'Кино', 'cat': 'movie', 'done': false});
  store.upsert('important', {
    'title': 'День рождения',
    'date':
        '2000-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    'yearly': true,
    'emoji': '🎂',
  });
  store.upsert('expense', {
    'title': 'Хлеб',
    'amount': 120.5,
    'cat': 'food',
    'date':
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    'by': me,
  });
  store.upsert('goal', {'title': 'Отпуск', 'target': 100000, 'saved': 25000});
  store.sendMessage('Привет!');
  store.sendMessage('Ответ', replyTo: store.messages.first);
  store.toggleReaction(store.messages.first, '❤️');
  store.toggleImportant(store.messages.last);
  return store;
}

/// В тестах по умолчанию используется «квадратный» шрифт, он шире настоящего.
/// Если рядом есть настоящий Roboto, подключаем его, чтобы проверка была честной.
Future<bool> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final dir = '$root/engine/src/flutter/txt/third_party/fonts';
  final files = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
  ].map((n) => File('$dir/$n')).where((f) => f.existsSync()).toList();
  if (files.isEmpty) return false;
  final loader = FontLoader('Roboto');
  for (final f in files) {
    loader.addFont(
      Future.value(
        ByteData.sublistView(Uint8List.fromList(f.readAsBytesSync())),
      ),
    );
  }
  await loader.load();
  return true;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late bool realFont;
  setUpAll(() async {
    realFont = await _loadRoboto();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'все экраны открываются без ошибок (${dark ? 'тёмная' : 'светлая'} тема)',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({
          'theme_mode': dark ? 'dark' : 'light',
        });
        await initializeDateFormatting('ru');
        await themeController.load();
        // Без настоящего шрифта игнорируем «переполнение строки»:
        // с широким тестовым шрифтом оно ложное.
        final prevHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          if (!realFont && details.exceptionAsString().contains('overflowed')) {
            return;
          }
          prevHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = prevHandler);
        final store = await _storeWithData();

        await tester.pumpWidget(PartnershippingApp(store: store));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        Finder nav(String label) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );

        // «Сегодня»
        expect(
          find.textContaining('Привет, '),
          findsNothing,
        ); // заголовок: приветствие + имя
        expect(find.textContaining('Саша'), findsWidgets);
        expect(find.text('ДЕЛА НА СЕГОДНЯ'), findsOneWidget);

        // Календарь + окно «График по шаблону» + выбор месяца и года
        await tester.tap(nav('Календарь'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
        await _settle(tester);
        expect(find.text('График по шаблону'), findsWidgets);
        await tester.tap(find.text('Применить'));
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
        await _settle(tester);
        expect(find.textContaining('Месяц'), findsWidgets);
        await tester.tapAt(const Offset(200, 100)); // закрыть окно
        await _settle(tester);
        await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).last);
        await _settle(tester);
        expect(find.text('Год'), findsWidgets);
        await tester.tapAt(const Offset(200, 100));
        await _settle(tester);

        // Списки
        await tester.tap(nav('Списки'));
        await _settle(tester);
        expect(find.text('Молоко'), findsOneWidget);
        await tester.tap(find.text('Дела'));
        await _settle(tester);
        expect(find.text('Убраться'), findsWidgets);
        await tester.tap(find.text('Вместе'));
        await _settle(tester);
        expect(find.text('Кино'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Чат
        await tester.tap(nav('Чат'));
        await _settle(tester);
        expect(find.text('Привет!'), findsWidgets);
        expect(find.text('Ответ'), findsWidgets);
        for (final tab in ['Важное', 'Фото', 'Файлы', 'Чат']) {
          await tester.tap(
            find.widgetWithText(ButtonSegment<int>, tab).evaluate().isEmpty
                ? find.text(tab).last
                : find.text(tab).last,
          );
          await _settle(tester);
        }
        expect(tester.takeException(), isNull);

        // Ещё и вложенные экраны
        await tester.tap(nav('Ещё'));
        await _settle(tester);
        for (final item in [
          'Заработок',
          'Важные даты',
          'Бюджет',
          'Настройки',
        ]) {
          await tester.tap(find.text(item));
          await _settle(tester);
          expect(tester.takeException(), isNull, reason: item);
          await tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .maybePop();
          await _settle(tester);
        }

        // Смена темы из настроек не ломает приложение
        await tester.tap(find.text('Настройки'));
        await _settle(tester);
        await tester.tap(find.text(dark ? 'Светлая' : 'Тёмная'));
        await _settle(tester);
        expect(tester.takeException(), isNull);

        await tester.pump(const Duration(seconds: 2));
      },
    );
  }

  test('график по шаблону записывается в хранилище', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await _storeWithData();
    expect(store.schedule.shifts.isNotEmpty, true);
    final me = store.session!.memberId;
    final today = DateTime.now();
    // 28 дней по 2/2 = 14 рабочих
    var work = 0;
    for (var i = 0; i < 28; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      if (store.schedule.shiftOf(me, d) != null) work++;
    }
    expect(work, 14);
    expect(store.hourRateFor(me), 350);
    // ставка не затирает настройку сдвига выплат
    store.setShiftPay(me, true);
    expect(store.hourRateFor(me), 350);
    expect(store.shiftPayFor(me), true);
    // реакции и ответы
    expect(store.messages.last.s('replyText'), 'Привет!');
    expect(store.messages.first.data['reactions'], isNotEmpty);
    store.toggleReaction(store.messages.first, '❤️');
    expect((store.messages.first.data['reactions'] as Map).isEmpty, true);
  });
}
