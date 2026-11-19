import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Дизайн кнопки-тапалки: цвета, значок и летящие символы.
class KissSkin {
  final String id;
  final String name;
  final String glyph; // значок на кнопке (для пряника рисуется кистью)
  final List<String> particles;
  final List<Color> colors;
  const KissSkin(this.id, this.name, this.glyph, this.particles, this.colors);

  bool get gingerbread => id == 'ginger';
}

const kKissSkins = <KissSkin>[
  KissSkin(
    'kiss',
    'Поцелуй',
    '💋',
    ['💋', '😘', '💕', '❤️', '💖', '😚'],
    [Color(0xFFFF9FB5), Color(0xFFF2849E)],
  ),
  KissSkin(
    'ginger',
    'Имбирный пряник',
    '🍪',
    ['🍪', '❄️', '⭐', '🍬', '🎄', '❤️'],
    [Color(0xFFE9B27A), Color(0xFFC98A4F)],
  ),
  KissSkin(
    'heart',
    'Сердечко',
    '❤️',
    ['❤️', '💗', '💖', '💘', '💝', '💞'],
    [Color(0xFFFF8A8A), Color(0xFFE85A71)],
  ),
  KissSkin(
    'teddy',
    'Мишка',
    '🧸',
    ['🧸', '🍯', '💛', '🐾', '⭐', '🤎'],
    [Color(0xFFF6D9A8), Color(0xFFE2B778)],
  ),
  KissSkin(
    'paw',
    'Оливка',
    '🐶',
    ['🐾', '🦴', '🐶', '💚', '🎾', '💛'],
    [Color(0xFFB7E0B0), Color(0xFF7FC48F)],
  ),
];

KissSkin kissSkinById(String? id) =>
    kKissSkins.firstWhere((s) => s.id == id, orElse: () => kKissSkins.first);

/// Выбранный дизайн (хранится на телефоне).
class KissSkinController extends ChangeNotifier {
  String _id = 'kiss';
  SharedPreferences? _prefs;

  KissSkin get skin => kissSkinById(_id);

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _id = _prefs!.getString('kiss_skin') ?? 'kiss';
    } catch (_) {}
  }

  void set(String id) {
    if (id == _id) return;
    _id = id;
    _prefs?.setString('kiss_skin', id);
    notifyListeners();
  }
}

final kissSkinController = KissSkinController();

/// Пряничный человечек, нарисованный кистью.
class GingerbreadMan extends StatelessWidget {
  final double size;
  const GingerbreadMan({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _GingerPainter());
}

class _GingerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset o(double x, double y) => Offset(x * w, y * h);
    final body = Paint()..color = const Color(0xFF9A5B2E);
    final edge = Paint()
      ..color = const Color(0xFFFFF4E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.028
      ..strokeCap = StrokeCap.round;
    // голова, туловище, руки и ноги
    final path = Path()
      ..addOval(Rect.fromCircle(center: o(0.5, 0.2), radius: w * 0.17))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.5, 0.52),
            width: w * 0.34,
            height: h * 0.4,
          ),
          Radius.circular(w * 0.1),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.24, 0.43),
            width: w * 0.36,
            height: h * 0.13,
          ),
          Radius.circular(w * 0.07),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.76, 0.43),
            width: w * 0.36,
            height: h * 0.13,
          ),
          Radius.circular(w * 0.07),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.38, 0.8),
            width: w * 0.17,
            height: h * 0.3,
          ),
          Radius.circular(w * 0.07),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: o(0.62, 0.8),
            width: w * 0.17,
            height: h * 0.3,
          ),
          Radius.circular(w * 0.07),
        ),
      );
    canvas.drawShadow(path, Colors.black54, 3, false);
    canvas.drawPath(path, body);
    // глазки, улыбка, пуговицы
    final eye = Paint()..color = const Color(0xFFFFF4E0);
    canvas.drawCircle(o(0.43, 0.18), w * 0.022, eye);
    canvas.drawCircle(o(0.57, 0.18), w * 0.022, eye);
    canvas.drawArc(
      Rect.fromCenter(center: o(0.5, 0.22), width: w * 0.16, height: h * 0.1),
      0.2,
      2.7,
      false,
      edge,
    );
    canvas.drawCircle(
      o(0.5, 0.43),
      w * 0.032,
      Paint()..color = const Color(0xFFE0505A),
    );
    canvas.drawCircle(
      o(0.5, 0.54),
      w * 0.032,
      Paint()..color = const Color(0xFF4DA06A),
    );
    canvas.drawCircle(
      o(0.5, 0.65),
      w * 0.032,
      Paint()..color = const Color(0xFFE0505A),
    );
    // глазурь на руках и ногах
    canvas.drawLine(o(0.1, 0.43), o(0.2, 0.43), edge);
    canvas.drawLine(o(0.8, 0.43), o(0.9, 0.43), edge);
    canvas.drawLine(o(0.36, 0.91), o(0.4, 0.91), edge);
    canvas.drawLine(o(0.6, 0.91), o(0.64, 0.91), edge);
    // бантик-шарфик
    final scarf = Paint()..color = const Color(0xFFE0505A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: o(0.5, 0.345),
          width: w * 0.26,
          height: h * 0.05,
        ),
        Radius.circular(w * 0.03),
      ),
      scarf,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
