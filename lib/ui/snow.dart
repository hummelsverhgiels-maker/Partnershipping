import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Мягкий снегопад поверх экрана для новогодней темы. Нажатия пропускает.
class SnowOverlay extends StatefulWidget {
  const SnowOverlay({super.key});

  @override
  State<SnowOverlay> createState() => _SnowOverlayState();
}

class _SnowOverlayState extends State<SnowOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SnowPainter(_c, kDark),
        ),
      ),
    );
  }
}

class _SnowPainter extends CustomPainter {
  final Animation<double> t;
  final bool dark;
  _SnowPainter(this.t, this.dark) : super(repaint: t);

  static const _n = 26;
  // фиксированные случайные параметры хлопьев
  static final List<List<double>> _f = () {
    final r = Random(7);
    return [
      for (var i = 0; i < _n; i++)
        [
          r.nextDouble(), // x
          r.nextDouble(), // сдвиг по времени
          1.2 + r.nextDouble() * 2.6, // радиус
          0.5 + r.nextDouble() * 1.0, // скорость
          r.nextDouble() * pi * 2, // фаза качания
        ],
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final base = dark ? Colors.white : const Color(0xFF9CC3DA);
    final p = Paint();
    final sec = t.value * 60;
    for (final f in _f) {
      final fall = ((sec / 18) * f[3] + f[1]) % 1.0;
      final y = fall * (size.height + 20) - 10;
      final x = f[0] * size.width + sin(sec * 0.8 * f[3] + f[4]) * 14;
      p.color = base.withValues(alpha: dark ? 0.55 : 0.5);
      canvas.drawCircle(Offset(x, y), f[2], p);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter old) => old.dark != dark;
}
