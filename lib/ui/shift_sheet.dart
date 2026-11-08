import 'package:flutter/material.dart';

import '../data/store.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

/// Окно ввода смены для одного или нескольких дней сразу.
Future<void> showShiftSheet(
  BuildContext context,
  AppStore store,
  List<DateTime> days, {
  String? memberId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ShiftSheet(store: store, days: days, memberId: memberId),
  );
}

class _ShiftSheet extends StatefulWidget {
  final AppStore store;
  final List<DateTime> days;
  final String? memberId;
  const _ShiftSheet({required this.store, required this.days, this.memberId});

  @override
  State<_ShiftSheet> createState() => _ShiftSheetState();
}

class _ShiftSheetState extends State<_ShiftSheet> {
  late String _member;
  String _start = '09:00';
  String _end = '21:00';
  bool _saveTemplate = false;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    _member = widget.memberId ?? s.session!.memberId;
    if (widget.days.length == 1) {
      final cur = s.schedule.shiftOf(_member, widget.days.first);
      if (cur != null) {
        _start = cur.start;
        _end = cur.end;
      }
    }
  }

  bool get _overnight => minutesOf(_end) <= minutesOf(_start);

  bool get _alreadyTemplate => s.templates.any(
    (t) =>
        t.s('memberId') == _member &&
        t.s('start') == _start &&
        t.s('end') == _end,
  );

  void _done() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final days = [...widget.days]..sort();
    final title = days.length == 1
        ? longDate(days.first)
        : '${days.length} ${plural(days.length, 'день', 'дня', 'дней')} выбрано';
    final myTemplates = s.templates
        .where((t) => t.s('memberId') == _member)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (days.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${days.first.day}.${days.first.month} — ${days.last.day}.${days.last.month}',
                  style: const TextStyle(color: kInkSoft),
                ),
              ),
            if (s.orderedMembers.length > 1) ...[
              const SectionTitle('Для кого'),
              Wrap(
                spacing: 10,
                children: [
                  for (final m in s.orderedMembers)
                    ChoiceChip(
                      avatar: ColorDot(m.color),
                      label: Text(
                        m.id == s.session!.memberId ? 'Я (${m.name})' : m.name,
                      ),
                      selected: _member == m.id,
                      onSelected: (_) => setState(() => _member = m.id),
                    ),
                ],
              ),
            ],
            const SectionTitle('Быстрые шаблоны'),
            if (myTemplates.isEmpty)
              const Text(
                'Пока нет. Задайте время и отметьте «Сохранить как шаблон».',
                style: TextStyle(color: kInkSoft),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in myTemplates)
                  InputChip(
                    label: Text('${t.s('start')}–${t.s('end')}'),
                    selected: t.s('start') == _start && t.s('end') == _end,
                    onPressed: () => setState(() {
                      _start = t.s('start')!;
                      _end = t.s('end')!;
                    }),
                    onDeleted: () async {
                      if (await confirm(context, 'Удалить шаблон?')) {
                        s.remove(t.id);
                        setState(() {});
                      }
                    },
                  ),
              ],
            ),
            const SectionTitle('Время смены'),
            Row(
              children: [
                Expanded(
                  child: _timeButton('Начало', _start, (v) => _start = v),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('—', style: TextStyle(fontSize: 22)),
                ),
                Expanded(child: _timeButton('Конец', _end, (v) => _end = v)),
              ],
            ),
            if (_overnight)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '🌙 Ночная смена: закончится на следующий день',
                  style: TextStyle(color: kInkSoft),
                ),
              ),
            if (!_alreadyTemplate)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _saveTemplate,
                onChanged: (v) => setState(() => _saveTemplate = v ?? false),
                title: const Text('Сохранить как шаблон'),
              ),
            const SizedBox(height: 12),
            Bouncy(
              child: FilledButton(
                onPressed: () {
                  if (_saveTemplate && !_alreadyTemplate) {
                    s.upsert('template', {
                      'memberId': _member,
                      'start': _start,
                      'end': _end,
                    });
                  }
                  s.setShift(_member, days, _start, _end);
                  _done();
                },
                child: const Text('Поставить смену'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Bouncy(
                    child: OutlinedButton(
                      onPressed: () {
                        s.setDayOff(_member, days);
                        _done();
                      },
                      child: const Text('Выходной'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Bouncy(
                    child: OutlinedButton(
                      onPressed: () {
                        s.clearDays(_member, days);
                        _done();
                      },
                      child: const Text('Очистить'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeButton(String label, String value, void Function(String) set) {
    return SoftCard(
      color: kAccentSoft,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      onTap: () async {
        final v = await pickTime(context, value);
        if (v != null) setState(() => set(v));
      },
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: kInkSoft, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
