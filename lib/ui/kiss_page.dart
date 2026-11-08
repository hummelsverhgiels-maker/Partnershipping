import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import 'avatar.dart';
import 'common.dart';
import 'theme.dart';

const _tapEmojis = ['💋', '😘', '💕', '❤️', '💖', '😚'];

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
        _tapEmojis[_rnd.nextInt(_tapEmojis.length)],
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

  String _cheer() {
    if (_session == 0) return 'Тапайте, чтобы отправить поцелуйчики';
    if (_session >= 100) return 'Сто поцелуйчиков! Вы чемпион нежности 🏆';
    if (_session >= 50) return 'Полсотни! Сердце партнёра тает 🥹';
    if (_session >= 25) return 'Вот это любовь! 💞';
    if (_session >= 10) return 'Ещё-ещё-ещё! 💕';
    return 'Отправлено, партнёр обрадуется 💌';
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
      appBar: AppBar(title: const Text('Поцелуи')),
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
                      child: Container(
                        width: 190,
                        height: 190,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF9FB5), Color(0xFFF2849E)],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 4,
                          ),
                        ),
                        child: const Text('💋', style: TextStyle(fontSize: 86)),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _cheer(),
                        key: ValueKey(_session == 0 ? 0 : (_session ~/ 5)),
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
