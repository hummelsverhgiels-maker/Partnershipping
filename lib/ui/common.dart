import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../util.dart';
import 'theme.dart';

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
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
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
            style: const TextStyle(
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
        GestureDetector(
          onTap: () => onChanged(c),
          child: Container(
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
            child: c == selected
                ? const Icon(Icons.check, color: kInk, size: 22)
                : null,
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
          style: const TextStyle(color: kInkSoft, fontSize: 15),
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
