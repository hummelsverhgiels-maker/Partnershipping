import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../util.dart';
import 'theme.dart';

/// Мягкое нажатие: элемент слегка «проминается» и возвращается плавно.
/// Работает на трансформации, поэтому почти ничего не стоит для телефона.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.965,
    this.haptic = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _interactive ? (_) => _set(true) : null,
      onTapUp: _interactive ? (_) => _set(false) : null,
      onTapCancel: _interactive ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              _set(false);
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 220),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Лёгкая «пружинка» для кнопок: слегка уменьшается, пока на неё нажимают.
/// Не перехватывает нажатия, поэтому кнопка внутри работает как обычно.
class Bouncy extends StatefulWidget {
  final Widget child;
  final double scale;
  const Bouncy({super.key, required this.child, this.scale = 0.97});

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 80 : 200),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Лёгкий переключатель: без теней и сложной отрисовки (быстрее на iPhone).
class SoftSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const SoftSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      scale: 0.93,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 52,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? kAccentDeep : kSwitchOff,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Строка «заголовок + пояснение + переключатель».
class SwitchRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  const SwitchRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 13,
                      color: kInkSoft,
                      height: 1.3,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SoftSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Мягкая карточка.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.975,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? kSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kCardBorder),
        ),
        child: child,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: kInkSoft,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class ColorDot extends StatelessWidget {
  final int color;
  final double size;
  const ColorDot(this.color, {super.key, this.size = 14});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
  );
}

class ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      for (final c in kMemberColors)
        PressScale(
          scale: 0.9,
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: c == selected ? kInk : Colors.transparent,
                width: 3,
              ),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: c == selected ? 1 : 0,
              child: Icon(Icons.check, color: kOnPastel, size: 22),
            ),
          ),
        ),
    ],
  );
}

class EmptyHint extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyHint(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: kInkSoft.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: kInkSoft, fontSize: 15),
        ),
      ],
    ),
  );
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
}

/// Выбор времени в 24-часовом формате.
Future<String?> pickTime(BuildContext context, String initial) async {
  final p = initial.split(':');
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
    helpText: 'Время',
    cancelText: 'Отмена',
    confirmText: 'Готово',
    hourLabelText: 'Часы',
    minuteLabelText: 'Минуты',
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return null;
  return fmtHm(t.hour, t.minute);
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
    locale: const Locale('ru'),
    helpText: 'Дата',
    cancelText: 'Отмена',
    confirmText: 'Готово',
  );
}

String longDate(DateTime d) {
  final s = DateFormat('EEEE, d MMMM', 'ru').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String monthTitle(DateTime d) {
  final s = DateFormat('LLLL yyyy', 'ru').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

Color softOn(int color) => Color(color);

/// Имя участника (или заглушка).
String nameOf(Member? m) => m?.name ?? 'Партнёр';

Future<bool> confirm(
  BuildContext context,
  String text, {
  String yes = 'Да',
  String no = 'Отмена',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(text, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}
