import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/pattern.dart';
import '../logic/stats.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

/// «График по шаблону»: 2/2, 3/3, сутки через трое, 5/2 или свой цикл.
Future<void> showPatternSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PatternSheet(store: store),
  );
}

class _PatternSheet extends StatefulWidget {
  final AppStore store;
  const _PatternSheet({required this.store});

  @override
  State<_PatternSheet> createState() => _PatternSheetState();
}

class _PatternSheetState extends State<_PatternSheet> {
  late String _member;
  int _preset = 0; // индекс в presets; -1 = свой цикл
  int _work = 2;
  int _off = 2;
  late DateTime _start;
  int _weeks = 8;
  String _from = '09:00';
  String _to = '21:00';
  bool _markOff = false;
  bool _replace = true;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    _member = s.session!.memberId;
    _start = dateOnly(DateTime.now());
  }

  SchedulePattern get _pattern => _preset >= 0
      ? SchedulePattern.presets[_preset]
      : SchedulePattern('$_work/$_off', _work, _off);

  PatternResult get _result =>
      generatePattern(start: _start, days: _weeks * 7, pattern: _pattern);

  bool get _overnight => minutesOf(_to) <= minutesOf(_from);

  String _dm(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final res = _result;
    final hoursPer = () {
      var d = minutesOf(_to) - minutesOf(_from);
      if (d <= 0) d += 1440;
      return d / 60.0;
    }();
    final last = addDays(_start, _weeks * 7 - 1);
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'График по шаблону',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Заполнит смены на несколько недель вперёд одним нажатием.',
                      style: TextStyle(color: kInkSoft),
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
                                m.id == s.session!.memberId
                                    ? 'Я (${m.name})'
                                    : m.name,
                              ),
                              selected: _member == m.id,
                              onSelected: (_) => setState(() => _member = m.id),
                            ),
                        ],
                      ),
                    ],
                    const SectionTitle('Шаблон'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < SchedulePattern.presets.length; i++)
                          ChoiceChip(
                            label: Text(SchedulePattern.presets[i].label),
                            selected: _preset == i,
                            onSelected: (_) => setState(() => _preset = i),
                          ),
                        ChoiceChip(
                          label: const Text('Свой'),
                          selected: _preset == -1,
                          onSelected: (_) => setState(() => _preset = -1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pattern.title,
                      style: TextStyle(color: kInkSoft, fontSize: 13),
                    ),
                    if (_preset == -1) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _stepper(
                              'Рабочих подряд',
                              _work,
                              (v) => setState(() => _work = v),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _stepper(
                              'Выходных подряд',
                              _off,
                              (v) => setState(() => _off = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SectionTitle('Время смены'),
                    if (myTemplates.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final t in myTemplates)
                              ActionChip(
                                label: Text('${t.s('start')}–${t.s('end')}'),
                                onPressed: () => setState(() {
                                  _from = t.s('start')!;
                                  _to = t.s('end')!;
                                }),
                              ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: _timeBox('Начало', _from, (v) => _from = v),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Text('—', style: TextStyle(fontSize: 22)),
                        ),
                        Expanded(child: _timeBox('Конец', _to, (v) => _to = v)),
                      ],
                    ),
                    if (_overnight)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '🌙 Ночная смена: закончится на следующий день',
                          style: TextStyle(color: kInkSoft),
                        ),
                      ),
                    const SectionTitle('Когда начать'),
                    Row(
                      children: [
                        Expanded(
                          child: Bouncy(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final d = await pickDate(context, _start);
                                if (d != null) {
                                  setState(() => _start = dateOnly(d));
                                }
                              },
                              icon: const Icon(Icons.event_outlined),
                              label: Text(_dm(_start)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _preset == -1 || !_pattern.weekdays
                          ? 'Это первый рабочий день цикла.'
                          : 'Будни считаются работой, Сб и Вс выходными.',
                      style: TextStyle(color: kInkSoft, fontSize: 13),
                    ),
                    const SectionTitle('На сколько недель'),
                    _stepper(
                      'Недель',
                      _weeks,
                      (v) => setState(() => _weeks = v),
                      min: 1,
                      max: 26,
                    ),
                    const SizedBox(height: 8),
                    SwitchRow(
                      value: _markOff,
                      onChanged: (v) => setState(() => _markOff = v),
                      title: const Text('Отметить выходные явно'),
                      subtitle: const Text(
                        'Появятся рамки «вых» в выходные дни шаблона',
                      ),
                    ),
                    SwitchRow(
                      value: _replace,
                      onChanged: (v) => setState(() => _replace = v),
                      title: const Text('Заменить прежние смены'),
                      subtitle: const Text(
                        'Старые смены в выходные дни шаблона будут убраны',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SoftCard(
                      color: kAccentSoft,
                      child: Text(
                        'Будет поставлено ${res.work.length} '
                        '${plural(res.work.length, 'смена', 'смены', 'смен')} '
                        'с ${_dm(_start)} по ${_dm(last)}'
                        ' · ${fmtHours(res.work.length * hoursPer)} всего',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: FilledButton(
                  onPressed: res.work.isEmpty
                      ? null
                      : () {
                          s.applyPattern(
                            memberId: _member,
                            workDays: res.work,
                            offDays: res.off,
                            start: _from,
                            end: _to,
                            markOff: _markOff,
                            clearOff: _replace,
                          );
                          Navigator.pop(context);
                          toast(
                            context,
                            'График заполнен: ${res.work.length} смен',
                          );
                        },
                  child: const Text('Применить'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepper(
    String label,
    int value,
    ValueChanged<int> onChanged, {
    int min = 1,
    int max = 14,
  }) {
    Widget btn(IconData icon, bool enabled, VoidCallback tap) => PressScale(
      scale: 0.85,
      onTap: enabled ? tap : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? kAccentSoft : kField,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: enabled ? kAccentDeep : kFaint),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          btn(Icons.remove_rounded, value > min, () => onChanged(value - 1)),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(label, style: TextStyle(fontSize: 11, color: kInkSoft)),
              ],
            ),
          ),
          btn(Icons.add_rounded, value < max, () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _timeBox(String label, String value, void Function(String) set) {
    return SoftCard(
      color: kAccentSoft,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      onTap: () async {
        final v = await pickTime(context, value);
        if (v != null) setState(() => set(v));
      },
      child: Column(
        children: [
          Text(label, style: TextStyle(color: kInkSoft, fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
