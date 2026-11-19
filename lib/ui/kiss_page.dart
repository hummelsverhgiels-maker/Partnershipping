import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import 'avatar.dart';
import 'common.dart';
import 'kiss_skin.dart';
import 'theme.dart';

/// Подпись под кнопкой: меняется на каждом круглом числе (10, 25, 50, 100, 200 … 1000 и дальше).
({int key, String text}) kissCheer(int n) {
  if (n <= 0) return (key: 0, text: 'Тапайте, чтобы отправить поцелуйчики');
  const milestones = <(int, String)>[
    (1, 'Отправлено, партнёр обрадуется 💌'),
    (10, 'Ещё-ещё-ещё! 💕'),
    (25, 'Вот это любовь! 💞'),
    (50, 'Полсотни! Сердце партнёра тает 🥹'),
    (100, 'Сто поцелуйчиков! Вы чемпион нежности 🏆'),
    (200, 'Двести! Партнёр уже в облаках ☁️💖'),
    (300, 'Триста! Это поцелуйная лавина 🌨️💋'),
    (400, 'Четыреста! Любовь не знает границ 🚀'),
    (500, 'Пятьсот! Половина тысячи нежности 🥰'),
    (600, 'Шестьсот! Грустить партнёр уже забыл как 😍'),
    (700, 'Семьсот! Вот это пальчики-чемпионы 💪💋'),
    (800, 'Восемьсот! Сердечко на максималках 💖💖💖'),
    (900, 'Девятьсот! До тысячи рукой подать 🔥'),
    (1000, 'ТЫСЯЧА поцелуйчиков! Вы легенда любви 👑💋'),
  ];
  if (n > 1000) {
    final base = n ~/ 100 * 100;
    if (base == 1000) {
      return (key: 1000, text: milestones.last.$2);
    }
    if (base % 1000 == 0) {
      return (
        key: base,
        text: '${base ~/ 1000} тыс. поцелуйчиков! Вы не остановитесь? 🤯💞',
      );
    }
    return (key: base, text: 'Уже больше $base! Остановиться невозможно 💋');
  }
  var best = milestones.first;
  for (final m in milestones) {
    if (n >= m.$1) best = m;
  }
  return (key: best.$1, text: best.$2);
}

class _Particle {
  final String emoji;
  final double dx; // горизонтальное смещение, px
  final double size;
  final int startMs;
  final int durMs;
  final bool incoming; // true: прилетает сверху (от партнёра)
  const _Particle(
    this.emoji,
    this.dx,
    this.size,
    this.startMs,
    this.durMs,
    this.incoming,
  );
}

/// Вкладка «Поцелуи»: тапайте по кнопке, и партнёр получит поцелуйчики.
class KissPage extends StatefulWidget {
  final AppStore store;
  final bool active; // вкладка сейчас открыта
  const KissPage({super.key, required this.store, required this.active});

  @override
  State<KissPage> createState() => _KissPageState();
}

class _KissPageState extends State<KissPage>
    with SingleTickerProviderStateMixin {
  final _rnd = Random();
  final List<_Particle> _ps = [];
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<int>? _sub;
  Timer? _flush;
  int _pending = 0; // тапы, ещё не отправленные на сервер
  int _session = 0; // тапы за время на этом экране

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      _elapsed = d;
      final now = d.inMilliseconds;
      _ps.removeWhere((p) => now - p.startMs > p.durMs);
      if (_ps.isEmpty) _ticker.stop();
      if (mounted) setState(() {});
    });
    _sub = s.kissReceived.listen((delta) {
      if (!mounted) return;
      _rain(min(delta, 36));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flush?.cancel();
    if (_pending > 0) s.sendKisses(_pending);
    _ticker.dispose();
    super.dispose();
  }

  int get _now => _ticker.isActive ? _elapsed.inMilliseconds : 0;

  void _ensureTicker() {
    if (!_ticker.isActive) {
      _elapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _addParticle(bool incoming) {
    _ensureTicker();
    _ps.add(
      _Particle(
        kissSkinController.skin.particles[_rnd.nextInt(
          kissSkinController.skin.particles.length,
        )],
        (_rnd.nextDouble() - 0.5) * (incoming ? 280 : 120),
        incoming ? 26 + _rnd.nextDouble() * 14 : 24 + _rnd.nextDouble() * 12,
        _now + (incoming ? _rnd.nextInt(700) : 0),
        incoming ? 1500 + _rnd.nextInt(600) : 1100 + _rnd.nextInt(300),
        incoming,
      ),
    );
  }

  void _rain(int n) {
    for (var i = 0; i < n; i++) {
      _addParticle(true);
    }
    HapticFeedback.heavyImpact();
    setState(() {});
  }

  void _tap() {
    HapticFeedback.mediumImpact();
    _addParticle(false);
    _pending++;
    _session++;
    if (_session % 100 == 0) _rain(30); // салют на каждой сотне
    // отправляем пачкой: через секунду после последнего тапа или каждые 15 тапов
    if (_pending >= 15) {
      _doFlush();
    } else {
      _flush?.cancel();
      _flush = Timer(const Duration(milliseconds: 900), _doFlush);
    }
    setState(() {});
  }

  void _doFlush() {
    _flush?.cancel();
    _flush = null;
    if (_pending > 0) {
      s.sendKisses(_pending);
      _pending = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active && s.kissUnseen > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.markKissesSeen());
    }
    final me = s.me;
    final partner = s.partner;
    final myToday = (me == null ? 0 : s.kissTodayOf(me.id)) + _pending;
    final myTotal = (me == null ? 0 : s.kissTotalOf(me.id)) + _pending;
    final theirTotal = partner == null ? 0 : s.kissTotalOf(partner.id);
    final theirToday = partner == null ? 0 : s.kissTodayOf(partner.id);
    final now = _now;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поцелуи'),
        actions: [
          IconButton(
            key: const ValueKey('kiss-skin'),
            tooltip: 'Дизайн кнопки',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showKissSkinSheet(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final cx = c.maxWidth / 2;
          final buttonTop = c.maxHeight * 0.36;
          return Stack(
            children: [
              ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _stat(
                          'Вы отправили',
                          '$myToday',
                          'сегодня · всего $myTotal',
                          me?.id,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _stat(
                          partner == null
                              ? 'Партнёр'
                              : '${partner.name} прислал(а)',
                          '$theirToday',
                          partner == null
                              ? 'ещё не подключён'
                              : 'сегодня · всего $theirTotal',
                          partner?.id,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: buttonTop,
                child: Column(
                  children: [
                    PressScale(
                      key: const ValueKey('kiss-button'),
                      scale: 0.86,
                      haptic: false,
                      onTap: _tap,
                      child: ListenableBuilder(
                        listenable: kissSkinController,
                        builder: (context, _) {
                          final skin = kissSkinController.skin;
                          return Container(
                            width: 190,
                            height: 190,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: skin.colors,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 4,
                              ),
                            ),
                            child: skin.gingerbread
                                ? const GingerbreadMan(size: 130)
                                : Text(
                                    skin.glyph,
                                    style: const TextStyle(fontSize: 86),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        kissCheer(_session).text,
                        key: ValueKey(kissCheer(_session).key),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kInkSoft,
                        ),
                      ),
                    ),
                    if (partner == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Партнёр увидит поцелуйчики, когда подключится к паре',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: kInkSoft),
                        ),
                      ),
                  ],
                ),
              ),
              // летящие поцелуйчики
              IgnorePointer(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final p in _ps)
                      if (now >= p.startMs)
                        _particleWidget(p, now, cx, buttonTop),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _particleWidget(_Particle p, int now, double cx, double buttonTop) {
    final t = ((now - p.startMs) / p.durMs).clamp(0.0, 1.0);
    final double y;
    final double opacity;
    final double scale;
    if (p.incoming) {
      // падают сверху к кнопке
      y = -30 + (buttonTop + 70) * Curves.easeIn.transform(t);
      opacity = t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1);
      scale = 0.8 + 0.5 * t;
    } else {
      // взлетают от кнопки вверх
      y = buttonTop + 40 - 300 * Curves.easeOut.transform(t);
      opacity = 1 - Curves.easeIn.transform(t);
      scale = 0.7 + 0.7 * t;
    }
    return Positioned(
      left: cx + p.dx - p.size / 2,
      top: y,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Text(p.emoji, style: TextStyle(fontSize: p.size)),
        ),
      ),
    );
  }

  Widget _stat(String label, String big, String sub, String? memberId) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (memberId != null)
                Avatar(store: s, memberId: memberId, size: 24),
              if (memberId != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kInkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            big,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          Text(sub, style: TextStyle(fontSize: 12, color: kInkSoft)),
        ],
      ),
    );
  }
}

/// Окно выбора дизайна тапалки.
Future<void> showKissSkinSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListenableBuilder(
        listenable: kissSkinController,
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Дизайн тапалки',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final k in kKissSkins)
                    PressScale(
                      key: ValueKey('skin-${k.id}'),
                      scale: 0.93,
                      onTap: () => kissSkinController.set(k.id),
                      child: Container(
                        width: 96,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kissSkinController.skin.id == k.id
                              ? kAccentSoft
                              : kField,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: kissSkinController.skin.id == k.id
                                ? kAccentDeep
                                : kBorder,
                            width: kissSkinController.skin.id == k.id ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: k.colors),
                              ),
                              child: k.gingerbread
                                  ? const GingerbreadMan(size: 42)
                                  : Text(
                                      k.glyph,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              k.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
