import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

/// Создание / правка события.
Future<void> showEventSheet(
  BuildContext context,
  AppStore s, {
  Rec? event,
  DateTime? date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventSheet(store: s, event: event, date: date),
  );
}

class _EventSheet extends StatefulWidget {
  final AppStore store;
  final Rec? event;
  final DateTime? date;
  const _EventSheet({required this.store, this.event, this.date});

  @override
  State<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<_EventSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  String? _time;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _title = TextEditingController(text: e?.s('title') ?? '');
    _note = TextEditingController(text: e?.s('note') ?? '');
    _date = e?.s('date') != null
        ? parseYmd(e!.s('date')!)
        : (widget.date ?? dateOnly(DateTime.now()));
    _time = e?.s('time');
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event == null ? 'Новое событие' : 'Событие',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: widget.event == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Название (поход, встреча, день рождения…)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Bouncy(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await pickDate(context, _date);
                        if (d != null) setState(() => _date = d);
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${_date.day}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Bouncy(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await pickTime(context, _time ?? '12:00');
                        if (t != null) setState(() => _time = t);
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text(_time ?? 'Время'),
                    ),
                  ),
                ),
                if (_time != null)
                  IconButton(
                    tooltip: 'Убрать время',
                    onPressed: () => setState(() => _time = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Заметка (необязательно)',
              ),
            ),
            const SizedBox(height: 16),
            Bouncy(
              child: FilledButton(
                onPressed: () {
                  final title = _title.text.trim();
                  if (title.isEmpty) {
                    toast(context, 'Введите название');
                    return;
                  }
                  widget.store.upsert('event', {
                    'title': title,
                    'date': ymd(_date),
                    if (_time != null) 'time': _time,
                    if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
                  }, id: widget.event?.id);
                  Navigator.pop(context);
                },
                child: const Text('Сохранить'),
              ),
            ),
            if (widget.event != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Удалить событие?',
                    yes: 'Удалить',
                  )) {
                    widget.store.remove(widget.event!.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFD9534F)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Создание / правка дела.
Future<void> showTodoSheet(
  BuildContext context,
  AppStore s, {
  Rec? todo,
  DateTime? date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TodoSheet(store: s, todo: todo, date: date),
  );
}

class _TodoSheet extends StatefulWidget {
  final AppStore store;
  final Rec? todo;
  final DateTime? date;
  const _TodoSheet({required this.store, this.todo, this.date});

  @override
  State<_TodoSheet> createState() => _TodoSheetState();
}

class _TodoSheetState extends State<_TodoSheet> {
  late final TextEditingController _title;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.todo?.s('title') ?? '');
    final d = widget.todo?.s('date');
    _date = d != null ? parseYmd(d) : widget.date;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, 'Введите, что нужно сделать');
      return;
    }
    final old = widget.todo;
    widget.store.upsert('todo', {
      ...?old?.data,
      'title': title,
      if (_date != null) 'date': ymd(_date!) else 'date': null,
    }, id: old?.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.todo == null ? 'Новое дело' : 'Дело',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.todo == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Например: убраться'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Bouncy(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await pickDate(
                        context,
                        _date ?? dateOnly(DateTime.now()),
                      );
                      if (d != null) setState(() => _date = d);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _date == null
                          ? 'Без даты'
                          : '${_date!.day}.${_date!.month.toString().padLeft(2, '0')}.${_date!.year}',
                    ),
                  ),
                ),
              ),
              if (_date != null)
                IconButton(
                  tooltip: 'Убрать дату',
                  onPressed: () => setState(() => _date = null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Bouncy(
            child: FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ),
          if (widget.todo != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  widget.store.remove(widget.todo!.id);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFD9534F)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Строка дела с галочкой; показывает, кто отметил.
class TodoTile extends StatelessWidget {
  final AppStore store;
  final Rec todo;
  final bool showDate;
  const TodoTile({
    super.key,
    required this.store,
    required this.todo,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final done = todo.b('done');
    final who = store.memberById(todo.s('doneBy'));
    final date = todo.s('date');
    final sub = <String>[
      if (showDate && date != null) longDate(parseYmd(date)),
      if (done && who != null) 'сделал(а): ${who.name}',
    ];
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      onTap: () => showTodoSheet(context, store, todo: todo),
      child: Row(
        children: [
          Checkbox(
            value: done,
            shape: const CircleBorder(),
            side: const BorderSide(color: kInkSoft, width: 2),
            onChanged: (v) {
              final nv = v ?? false;
              store.upsert('todo', {
                ...todo.data,
                'done': nv,
                'doneBy': nv ? store.session?.memberId : null,
                'doneAt': nv ? DateTime.now().toIso8601String() : null,
              }, id: todo.id);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                    color: done ? kInkSoft : kInk,
                  ),
                  child: Text(todo.s('title') ?? ''),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub.join(' · '),
                    style: const TextStyle(fontSize: 13, color: kInkSoft),
                  ),
              ],
            ),
          ),
          if (done && who != null) ColorDot(who.color),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
