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
import 'ui/theme_controller.dart';

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
  await themeController.load();
  final store = AppStore();
  await store.init();
  // Firebase грузится в фоне: если серверы Google недоступны, приложение всё равно запустится.
  unawaited(
    PushService.init(store)
        .timeout(const Duration(seconds: 15), onTimeout: () {}),
  );
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
    widget.store.onKissReceived = (who, delta) {
      // Если включены мгновенные уведомления, их присылает сервер.
      if (PushService.active) return;
      // Когда приложение открыто, поцелуйчики и так видны на экране.
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        return;
      }
      if (widget.store.getFlag('notif_partner')) {
        Notifier.showKiss(who, delta);
      }
    };
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
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    return MaterialApp(
      key: ValueKey(themeController.isDark),
      title: 'V&V loving planning',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scrollBehavior: const SoftScrollBehavior(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      builder: (context, child) {
        // Общий мягкий фон: лёгкий градиент от персикового к кремовому.
        final bg = DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kBgTop, kBg, kBg],
              stops: [0, 0.35, 1],
            ),
          ),
          child: child,
        );
        if (!kIsWeb) return bg;
        // В браузере на большом экране держим приложение «телефонной» ширины.
        return ColoredBox(
          color: kBg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: bg,
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
