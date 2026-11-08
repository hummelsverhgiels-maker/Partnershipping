import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/schedule.dart';
import '../util.dart';
import 'common.dart';
import 'day_page.dart';
import 'shift_sheet.dart';
import 'theme.dart';

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

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

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

    return Scaffold(
      appBar: AppBar(
        leading: selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        title: Text(selecting ? 'Выбрано: ${_selected.length}' : 'Календарь'),
        actions: [
          if (!selecting)
            TextButton(
              onPressed: () {
                final n = DateTime.now();
                setState(() => _month = DateTime(n.year, n.month));
              },
              child: const Text('Сегодня'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left, size: 30),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthTitle(_month),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right, size: 30),
                ),
              ],
            ),
          ),
          _legend(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (final w in ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'])
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: const TextStyle(
                          color: kInkSoft,
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
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) _shiftMonth(1);
                if (v > 200) _shiftMonth(-1);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
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
          if (selecting)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: FilledButton.icon(
                  onPressed: () async {
                    final d = _selectedDays;
                    await showShiftSheet(context, s, d);
                    _clearSelection();
                  },
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text('Смена или выходной для ${_selected.length} дн.'),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Нажмите на день, чтобы открыть. Удерживайте, чтобы выбрать несколько.',
                style: TextStyle(color: kInkSoft, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend() {
    final ms = s.orderedMembers;
    if (ms.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final m in ms) ...[
            ColorDot(m.color, size: 12),
            const SizedBox(width: 6),
            Text(
              m.id == s.session?.memberId ? 'Я' : m.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
          ],
          const Text(
            '₽ выплата',
            style: TextStyle(fontSize: 12, color: kInkSoft),
          ),
          const SizedBox(width: 10),
          const Text(
            '● событие',
            style: TextStyle(fontSize: 12, color: kInkSoft),
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime d, List<PayItem> pays, bool hasEvent, bool hasTodo) {
    final inMonth = d.month == _month.month;
    final isToday = dateOnly(d) == dateOnly(DateTime.now());
    final sel = _selected.contains(ymd(d));
    final ms = s.orderedMembers;

    return GestureDetector(
      onTap: () {
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
      },
      onLongPress: () => _longPress(d),
      child: Opacity(
        opacity: inMonth ? 1 : 0.4,
        child: Container(
          margin: const EdgeInsets.all(1.5),
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
          decoration: BoxDecoration(
            color: sel ? kAccentSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel
                  ? const Color(0xFFE58E70)
                  : isToday
                  ? const Color(0xFFE58E70)
                  : Colors.transparent,
              width: sel || isToday ? 2 : 0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 2),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (pays.isNotEmpty)
                    const Text(
                      '₽',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97B5C),
                      ),
                    ),
                  if (hasEvent)
                    const Text(
                      '●',
                      style: TextStyle(fontSize: 9, color: Color(0xFF8FB8E8)),
                    ),
                  if (hasTodo)
                    const Text(
                      '✓',
                      style: TextStyle(fontSize: 10, color: Color(0xFF7DBE8B)),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              for (final m in ms) Expanded(child: _chip(m.id, m.color, d)),
              if (ms.isEmpty) const Spacer(),
            ],
          ),
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
      bg = Color(color).withValues(alpha: 0.22);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(7),
      ),
      child: text == null
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: kInk,
                  ),
                ),
              ),
            ),
    );
  }
}
