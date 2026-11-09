import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:partnershipping/data/store.dart';
import 'package:partnershipping/logic/pattern.dart';
import 'package:partnershipping/main.dart';
import 'package:partnershipping/ui/feed_page.dart';
import 'package:partnershipping/ui/more_page.dart';
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
  store.createPost('Первая публикация', const []);
  store.addDocLink(
    title: 'Паспорт (ссылка)',
    url: 'https://drive.google.com/x',
    cat: 'id',
  );
  store.setMood(80);
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
  AppStore.saveDelay = Duration.zero;
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

        Finder nav(String label) => find.byKey(ValueKey('tab-$label'));
        Finder moreScroll() => find
            .descendant(
              of: find.byType(MorePage),
              matching: find.byType(Scrollable),
            )
            .first;
        Future<void> back() async {
          await tester
              .state<NavigatorState>(find.byType(Navigator).first)
              .maybePop();
          await _settle(tester);
        }

        Future<void> moreItem(String title) async {
          await tester.scrollUntilVisible(
            find.text(title),
            200,
            scrollable: moreScroll(),
          );
          await _settle(tester);
          await tester.tap(find.text(title));
          await _settle(tester);
        }

        // «Сегодня»
        expect(
          find.textContaining('Привет, '),
          findsNothing,
        ); // заголовок: приветствие + имя
        expect(find.textContaining('Саша'), findsWidgets);
        expect(find.text('НАСТРОЕНИЕ'), findsOneWidget);
        expect(find.byKey(const ValueKey('together-card')), findsOneWidget);

        // Настроение: «+» открывает выбор состояний, выбранное сохраняется
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('mood-plus')),
          find.byType(ListView).first,
          const Offset(0, -150),
        );
        await tester.tap(find.byKey(const ValueKey('mood-plus')));
        await _settle(tester);
        expect(find.text('Что со мной сейчас?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('mood-tag-hungry')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('mood-tag-tired')));
        await _settle(tester);
        expect(store.moodTagsOf(store.session!.memberId), ['hungry', 'tired']);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(200, 60)); // закрыть окно
        await _settle(tester);

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

        // Поцелуи теперь в «Ещё»: тап по кнопке увеличивает счётчик
        await tester.tap(nav('Ещё'));
        await _settle(tester);
        await tester.tap(find.text('Поцелуи'));
        await _settle(tester);
        final kissesBefore = store.kissTotalOf(store.session!.memberId);
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const ValueKey('kiss-button')));
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.pump(
          const Duration(milliseconds: 1200),
        ); // пачка уходит через секунду
        expect(store.kissTotalOf(store.session!.memberId), kissesBefore + 3);
        await tester.pump(const Duration(seconds: 3)); // частицы улетели
        expect(tester.takeException(), isNull);
        await tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .maybePop();
        await _settle(tester);

        // Лента: публикация, лайк, комментарии
        await tester.tap(nav('Лента'));
        await _settle(tester);
        expect(find.text('Первая публикация'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.descendant(
            of: find.byType(PostCard),
            matching: find.byIcon(Icons.favorite_border_rounded),
          ),
        );
        await _settle(tester);
        expect(store.postLikedByMe(store.posts.first), true);
        await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
        await _settle(tester);
        expect(find.text('Комментарии'), findsWidgets);
        await tester.tapAt(const Offset(200, 100));
        await _settle(tester);

        // Документы (в «Ещё»)
        await tester.tap(nav('Ещё'));
        await _settle(tester);
        await tester.tap(find.text('Документы'));
        await _settle(tester);
        expect(find.text('Паспорт (ссылка)'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .maybePop();
        await _settle(tester);

        // Собака (в «Ещё»): отметки, план выгула, здоровье, запасы, паспорт
        await tester.tap(nav('Ещё'));
        await _settle(tester);
        final today = DateTime.now();
        await tester.tap(find.text('Собака сегодня'));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('dog-item-walk_m')));
        await _settle(tester);
        expect(store.dogDoneOf(today, 'walk_m'), isNotNull);
        expect(tester.takeException(), isNull);
        await back();

        await moreItem('Кто гуляет');
        final slot = find.byKey(
          ValueKey(
            'slot-${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}-e',
          ),
        );
        await tester.tap(slot);
        await _settle(tester);
        await tester.tap(find.text('Гуляю я'));
        await _settle(tester);
        expect(store.dogPlanOf(today, 'e'), store.session!.memberId);
        expect(find.textContaining('договорились'), findsWidgets);
        expect(tester.takeException(), isNull);
        await back();

        await moreItem('Здоровье');
        await tester.tap(find.text('Добавить основные'));
        await _settle(tester);
        expect(store.dogCare.length, 4);
        await tester.tap(find.text('Сделано').first);
        await _settle(tester);
        expect(store.dogCare.where((r) => r.s('last') != null).length, 1);
        await tester.tap(find.text('Процедура'));
        await _settle(tester);
        expect(find.text('Новая процедура'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await back(); // закрыть окно
        expect(tester.takeException(), isNull);
        await back();

        await moreItem('Запасы');
        await tester.tap(find.text('Добавить корм, лакомства, пакеты'));
        await _settle(tester);
        expect(store.dogSupplies.length, 4);
        await tester.tap(find.text('В покупки').first);
        await _settle(tester);
        expect(
          store.shopping
              .where((r) => (r.s('title') ?? '').contains('корм'))
              .length,
          1,
        );
        expect(tester.takeException(), isNull);
        await back();

        await moreItem('Паспорт собаки');
        await tester.enterText(find.byType(TextField).first, 'Бублик');
        await tester.tap(find.text('Сохранить').first);
        await _settle(tester);
        expect(store.dogName, 'Бублик');
        expect(tester.takeException(), isNull);
        await back();
        await tester.scrollUntilVisible(
          find.text('Бублик сегодня'),
          -200,
          scrollable: moreScroll(),
        );
        expect(find.text('Бублик сегодня'), findsOneWidget);

        // Новые разделы: поза дня, видео, заметки, благодарности, идеи, дни рождения, копия
        await moreItem('Поза дня');
        expect(find.textContaining('Снимайте'), findsOneWidget);
        await back();
        await moreItem('Видео-альбом');
        expect(find.textContaining('видео вашей собаки'), findsOneWidget);
        await back();
        await moreItem('Заметки о собаке');
        store.upsert('dognote', {
          'cat': 'cmd',
          'title': 'Дай лапу',
          'text': 'Учим',
          'ts': 1,
        });
        await _settle(tester);
        expect(find.text('Дай лапу'), findsOneWidget);
        await back();
        await moreItem('Банка благодарностей');
        store.upsert('thanks', {
          'title': 'ужин',
          'by': store.session!.memberId,
          'date': '2026-11-01',
          'ts': 1,
        });
        await _settle(tester);
        expect(find.text('Спасибо за ужин'), findsOneWidget);
        await back();
        await moreItem('Идеи для свиданий');
        await tester.tap(find.byKey(const ValueKey('idea-roll')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('idea-went')));
        await _settle(tester);
        expect(store.kindList('dateidea').where((r) => r.b('done')).length, 1);
        expect(tester.takeException(), isNull);
        await back();
        await moreItem('Дни рождения');
        store.upsert('person', {
          'name': 'Мама',
          'rel': 'мама',
          'date': '1970-03-08',
          'ts': 1,
        });
        await _settle(tester);
        expect(find.textContaining('Мама'), findsOneWidget);
        await back();
        await moreItem('Резервная копия');
        expect(find.text('Сохранить копию в файл'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await back();

        // Ещё и вложенные экраны
        for (final item in [
          'Заработок',
          'Важные даты',
          'Бюджет',
          'Настройки',
        ]) {
          await moreItem(item);
          expect(tester.takeException(), isNull, reason: item);
          await back();
        }
        // карточка собаки на «Сегодня»
        await tester.tap(nav('Сегодня'));
        await _settle(tester);
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('dog-today-card')),
          find.byType(ListView).first,
          const Offset(0, -150),
        );
        expect(find.text('Бублик сегодня'), findsWidgets);
        await tester.tap(nav('Ещё'));
        await _settle(tester);
        await tester.scrollUntilVisible(
          find.text('Настройки'),
          200,
          scrollable: moreScroll(),
        );
        await _settle(tester);

        // Аватарка: окно выбора открывается, картинка выбирается и видна в профиле
        store.setAvatar('emoji:🦊');
        await tester.tap(find.text('Настройки'));
        await _settle(tester);
        expect(find.text('🦊'), findsWidgets);
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await _settle(tester);
        await tester.tap(find.text('Сменить аватарку'));
        await _settle(tester);
        expect(find.text('Аватарка'), findsWidgets);
        await tester.tap(find.text('🐼'));
        await _settle(tester);
        expect(store.avatarOf(store.session!.memberId), 'emoji:🐼');
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(200, 60)); // закрыть окно выбора
        await _settle(tester);
        await tester.tapAt(const Offset(200, 60)); // закрыть окно профиля
        await _settle(tester);
        await tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .maybePop();
        await _settle(tester);

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
    // аватарки
    expect(store.avatarOf(me), '');
    store.setAvatar('emoji:🐱');
    expect(store.avatarOf(me), 'emoji:🐱');
    store.setAvatar('');
    expect(store.avatarOf(me), '');
    store.setAvatar('emoji:🦊');
    // состояния настроения не затирают ползунок и наоборот
    store.setMood(70);
    store.setMoodTags(['hungry', 'tired']);
    expect(store.moodOf(me), 70);
    expect(store.moodTagsOf(me), ['hungry', 'tired']);
    store.setMood(30);
    expect(store.moodTagsOf(me), ['hungry', 'tired']);
    store.setMoodTags(const []);
    expect(store.moodOf(me), 30);
    expect(store.moodTagsOf(me), isEmpty);
    store.setMood(80);
    // настроение и документы
    expect(store.moodOf(me), 80);
    store.setMood(15);
    expect(store.moodOf(me), 15);
    expect(store.posts.length, 1);
    expect(store.docs.length, 1);
    // реакции и ответы
    expect(store.messages.last.s('replyText'), 'Привет!');
    expect(store.messages.first.data['reactions'], isNotEmpty);
    store.toggleReaction(store.messages.first, '❤️');
    expect((store.messages.first.data['reactions'] as Map).isEmpty, true);
  });
}
