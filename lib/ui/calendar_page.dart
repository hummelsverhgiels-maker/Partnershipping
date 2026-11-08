import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../logic/schedule.dart';
import '../util.dart';
import 'common.dart';
import 'day_page.dart';
import 'pattern_sheet.dart';
import 'shift_sheet.dart';
import 'theme.dart';

const _monthShort = [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];

class CalendarPage extends StatefulWidget {
  final AppStore store;
  const CalendarPage({super.key, required this.store});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month;
  final Set<String> _selected = {};
  String? _lastSelected;
  int _dir = 1; // куда «уезжает» календарь при смене месяца

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _goTo(DateTime m) {
    final target = DateTime(m.year, m.month);
    if (target == _month) return;
    setState(() {
      _dir = target.isAfter(_month) ? 1 : -1;
      _month = target;
    });
  }

  void _shiftMonth(int delta) =>
      _goTo(DateTime(_month.year, _month.month + delta));

  /// 42 клетки, неделя с понедельника.
  List<DateTime> _gridDays() {
    final first = DateTime(_month.year, _month.month, 1);
    final start = addDays(first, -(first.weekday - 1));
    return [for (var i = 0; i < 42; i++) addDays(start, i)];
  }

  void _toggle(DateTime d) {
    final k = ymd(d);
    setState(() {
      if (!_selected.remove(k)) {
        _selected.add(k);
        _lastSelected = k;
      }
      if (_selected.isEmpty) _lastSelected = null;
    });
  }

  void _longPress(DateTime d) {
    final k = ymd(d);
    setState(() {
      if (_selected.isEmpty || _lastSelected == null) {
        _selected.add(k);
      } else {
        // выбор диапазона от последнего отмеченного дня до этого
        var a = parseYmd(_lastSelected!);
        var b = d;
        if (b.isBefore(a)) {
          final t = a;
          a = b;
          b = t;
        }
        for (var x = a; !x.isAfter(b); x = addDays(x, 1)) {
          _selected.add(ymd(x));
        }
      }
      _lastSelected = k;
    });
  }

  void _clearSelection() => setState(() {
    _selected.clear();
    _lastSelected = null;
  });

  List<DateTime> get _selectedDays =>
      (_selected.map(parseYmd).toList()..sort());

  // ------------------------------------------------------ выбор месяца и года
  Future<void> _pickMonth() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Месяц · ${_month.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  for (var m = 1; m <= 12; m++)
                    _pickChip(
                      _monthShort[m - 1],
                      selected: m == _month.month,
                      current:
                          m == DateTime.now().month &&
                          _month.year == DateTime.now().year,
                      onTap: () => Navigator.pop(ctx, m),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _goTo(DateTime(_month.year, picked));
  }

  Future<void> _pickYear() async {
    final now = DateTime.now().year;
    final years = [for (var y = now - 6; y <= now + 9; y++) y];
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Год',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  for (final y in years)
                    _pickChip(
                      '$y',
                      selected: y == _month.year,
                      current: y == now,
                      onTap: () => Navigator.pop(ctx, y),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) _goTo(DateTime(picked, _month.month));
  }

  Widget _pickChip(
    String label, {
    required bool selected,
    required bool current,
    required VoidCallback onTap,
  }) {
    return PressScale(
      scale: 0.93,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? kAccentDeep : kField,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? kAccentDeep
                : current
                ? kAccent
                : kLine,
            width: current && !selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : kInk,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- вёрстка
  @override
  Widget build(BuildContext context) {
    final selecting = _selected.isNotEmpty;
    final days = _gridDays();
    final pays = s.schedule.paymentsInRange(days.first, days.last);
    final payByDate = <String, List<PayItem>>{};
    for (final p in pays) {
      (payByDate[ymd(p.date)] ??= []).add(p);
    }
    final eventDates = {for (final e in s.events) e.s('date')};
    final todoDates = {
      for (final t in s.todos)
        if (!t.b('done')) t.s('date'),
    };
    final now = DateTime.now();
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSelection,
              )
            : null,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            selecting ? 'Выбрано: ${_selected.length}' : 'Календарь',
            key: ValueKey(selecting),
          ),
        ),
        actions: [
          if (!selecting)
            IconButton(
              tooltip: 'График по шаблону',
              onPressed: () => showPatternSheet(context, s),
              icon: const Icon(Icons.auto_awesome_rounded),
            ),
          if (!selecting && !isCurrentMonth)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: kAccentSoft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () => _goTo(DateTime(now.year, now.month)),
                child: const Text('Сегодня'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Row(
              children: [
                _roundButton(Icons.chevron_left_rounded, () => _shiftMonth(-1)),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _headerPill(_monthName(_month), _pickMonth),
                        const SizedBox(width: 8),
                        _headerPill('${_month.year}', _pickYear),
                      ],
                    ),
                  ),
                ),
                _roundButton(Icons.chevron_right_rounded, () => _shiftMonth(1)),
              ],
            ),
          ),
          _legend(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i],
                        style: TextStyle(
                          color: i >= 5 ? const Color(0xFFD9805F) : kInkSoft,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(0.05 * _dir, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(
                  key: ValueKey('${_month.year}-${_month.month}'),
                  child: Column(
                    children: [
                      for (var r = 0; r < 6; r++)
                        Expanded(
                          child: Row(
                            children: [
                              for (var c = 0; c < 7; c++)
                                Expanded(
                                  child: _cell(
                                    days[r * 7 + c],
                                    payByDate[ymd(days[r * 7 + c])] ?? const [],
                                    eventDates.contains(ymd(days[r * 7 + c])),
                                    todoDates.contains(ymd(days[r * 7 + c])),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selecting
                ? SafeArea(
                    key: const ValueKey('bar'),
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: Bouncy(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final d = _selectedDays;
                              await showShiftSheet(context, s, d);
                              _clearSelection();
                            },
                            icon: const Icon(Icons.edit_calendar_outlined),
                            label: Text(
                              'Смена или выходной · ${_selected.length} дн.',
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    key: ValueKey('hint'),
                    padding: EdgeInsets.only(bottom: 8, top: 2),
                    child: Text(
                      'Нажмите на день, чтобы открыть. Удерживайте, чтобы выбрать несколько.',
                      style: TextStyle(color: kInkSoft, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _monthName(DateTime d) {
    final t = DateFormat('LLLL', 'ru').format(d);
    return t[0].toUpperCase() + t.substring(1);
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return PressScale(
      scale: 0.88,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kSurface,
          shape: BoxShape.circle,
          border: Border.all(color: kLine),
        ),
        child: Icon(icon, size: 28, color: kInk),
      ),
    );
  }

  Widget _headerPill(String text, VoidCallback onTap) {
    return PressScale(
      scale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: kInkSoft),
          ],
        ),
      ),
    );
  }

  Widget _legend() {
    final ms = s.orderedMembers;
    if (ms.isEmpty) return const SizedBox(height: 6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final m in ms) ...[
            ColorDot(m.color, size: 12),
            const SizedBox(width: 6),
            Text(
              m.id == s.session?.memberId ? 'Я' : m.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 14),
          ],
          Text('₽ выплата', style: TextStyle(fontSize: 12, color: kInkSoft)),
          const SizedBox(width: 10),
          Text('● событие', style: TextStyle(fontSize: 12, color: kInkSoft)),
          if (ms.length == 2) ...[
            const SizedBox(width: 10),
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: kCommon,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: kBorder),
              ),
            ),
            const SizedBox(width: 4),
            Text('вместе', style: TextStyle(fontSize: 12, color: kInkSoft)),
          ],
        ],
      ),
    );
  }

  Widget _cell(DateTime d, List<PayItem> pays, bool hasEvent, bool hasTodo) {
    final inMonth = d.month == _month.month;
    final isToday = dateOnly(d) == dateOnly(DateTime.now());
    final sel = _selected.contains(ymd(d));
    final ms = s.orderedMembers;
    final weekend = d.weekday >= 6;
    final common =
        ms.length == 2 && s.schedule.isCommonOff(ms[0].id, ms[1].id, d);
    final hasImportant = s.importantOn(d).isNotEmpty;

    void onTap() {
      if (_selected.isNotEmpty) {
        _toggle(d);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => DayPage(store: s, date: dateOnly(d)),
          ),
        );
      }
    }

    // Дни соседних месяцев: только бледное число, без полосок.
    if (!inMonth) {
      return PressScale(
        scale: 0.95,
        onTap: onTap,
        onLongPress: () => _longPress(d),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          padding: const EdgeInsets.fromLTRB(6, 5, 3, 3),
          decoration: BoxDecoration(
            color: sel ? kAccentSoft : kOutMonth,
            borderRadius: BorderRadius.circular(16),
            border: sel ? Border.all(color: kAccentDeep, width: 2) : null,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kFaint,
              ),
            ),
          ),
        ),
      );
    }

    return PressScale(
      scale: 0.93,
      onTap: onTap,
      onLongPress: () => _longPress(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
        decoration: BoxDecoration(
          color: sel ? kAccentSoft : (common ? kCommon : kSurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: sel ? kAccentDeep : (isToday ? kAccent : kLine),
            width: sel ? 2 : (isToday ? 1.6 : 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isToday ? kAccentDeep : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                      color: isToday
                          ? Colors.white
                          : (weekend ? const Color(0xFFD9805F) : kInk),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (pays.isNotEmpty)
                            const Text(
                              '₽',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD97B5C),
                              ),
                            ),
                          if (hasImportant)
                            const Text(
                              '★',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFFE0A030),
                              ),
                            ),
                          if (hasEvent)
                            const Text(
                              '●',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF8FB8E8),
                              ),
                            ),
                          if (hasTodo)
                            const Text(
                              '✓',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF7DBE8B),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            for (final m in ms) Expanded(child: _chip(m.id, m.color, d)),
            if (ms.isEmpty) const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _chip(String memberId, int color, DateTime d) {
    final shift = s.schedule.shiftOf(memberId, d);
    final off = s.schedule.explicitOff(memberId, d);
    String? text;
    Color bg;
    BoxBorder? border;
    if (shift != null) {
      text = compactTime(shift.start, shift.end);
      bg = Color(color);
    } else if (off) {
      text = 'вых';
      bg = Colors.transparent;
      border = Border.all(color: Color(color), width: 1.6);
    } else {
      bg = Color(color).withValues(alpha: 0.20);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(9),
      ),
      child: text == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    // на цветной плашке текст тёмный, на пустой рамке «вых» зависит от темы
                    color: shift != null ? kOnPastel : kInkSoft,
                  ),
                ),
              ),
            ),
    );
  }
}
