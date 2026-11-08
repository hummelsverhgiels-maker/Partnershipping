import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/backend.dart';
import 'data/store.dart';
import 'services/notifier.dart';
import 'services/push_service.dart';
import 'services/widget_service.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  try {
    await Backend.init();
  } catch (e) {
    debugPrint('Supabase не запущен: $e');
  }
  try {
    await Notifier.init();
  } catch (e) {
    debugPrint('Уведомления не запущены: $e');
  }
  final store = AppStore();
  await store.init();
  await PushService.init(store);
  runApp(PartnershippingApp(store: store));
}

class PartnershippingApp extends StatefulWidget {
  final AppStore store;
  const PartnershippingApp({super.key, required this.store});

  @override
  State<PartnershippingApp> createState() => _PartnershippingAppState();
}

class _PartnershippingAppState extends State<PartnershippingApp>
    with WidgetsBindingObserver {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_onChanged);
    widget.store.onPartnerChange = (who, cats) {
      // Если включены мгновенные уведомления (Firebase), их присылает сервер.
      if (PushService.active) return;
      if (widget.store.getFlag('notif_partner')) {
        final msgs = widget.store.messages;
        Notifier.showPartnerChange(
          who,
          cats,
          lastMessage: msgs.isEmpty ? null : msgs.last.s('text'),
        );
      }
    };
    if (widget.store.hasSession) {
      Notifier.requestPermission();
      if (!kIsWeb) PushService.requestPermission(widget.store);
      _onChanged();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_onChanged);
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.store.refresh();
      _onChanged();
    }
  }

  /// После любых изменений: обновить виджет и напоминания о выплатах.
  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      if (!widget.store.hasSession) return;
      WidgetService.update(widget.store);
      PushService.sync(widget.store);
      Notifier.reschedulePay(widget.store);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V&V loving planning',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      builder: (context, child) {
        if (!kIsWeb) return child!;
        // В браузере на большом экране держим приложение «телефонной» ширины.
        return ColoredBox(
          color: const Color(0xFFFFF8F3),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: child,
            ),
          ),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          if (!widget.store.loaded) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!widget.store.hasSession) {
            return OnboardingScreen(store: widget.store);
          }
          // Первый вход: сразу просим разрешение на уведомления.
          return HomeShell(store: widget.store);
        },
      ),
    );
  }
}
