import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/important.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

const _emojis = [
  '🎂',
  '💍',
  '❤️',
  '✈️',
  '🏖️',
  '🎉',
  '🎁',
  '🏠',
  '🐶',
  '🎓',
  '🎄',
  '⭐',
];

/// Важные даты: дни рождения, годовщины, отпуск, с обратным отсчётом.
class ImportantPage extends StatelessWidget {
  final AppStore store;
  const ImportantPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final items = <(Rec, DateTime?)>[
          for (final r in store.importantDates)
            if (r.s('date') != null)
              (r, nextOccurrence(parseYmd(r.s('date')!), r.b('yearly'), today)),
        ];
        items.sort((a, b) {
          if (a.$2 == null && b.$2 == null) return 0;
          if (a.$2 == null) return 1;
          if (b.$2 == null) return -1;
          return a.$2!.compareTo(b.$2!);
        });
        return Scaffold(
          appBar: AppBar(
            title: const Text('Важные даты'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => showImportantSheet(context, store),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Добавить',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: items.isEmpty
              ? const Center(
                  child: EmptyHint(
                    'Добавьте дни рождения, годовщину, отпуск.\nПриложение посчитает, сколько осталось.',
                    icon: Icons.cake_outlined,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    for (final it in items) ...[
                      _tile(context, it.$1, it.$2, today),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, Rec r, DateTime? next, DateTime today) {
    final orig = parseYmd(r.s('date')!);
    final yearly = r.b('yearly');
    final days = next == null ? null : daysUntil(next, today);
    final years = (yearly && next != null) ? yearsAt(orig, next) : 0;
    final dateText =
        '${orig.day}.${orig.month.toString().padLeft(2, '0')}.${orig.year}';
    return SoftCard(
      onTap: () => showImportantSheet(context, store, existing: r),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kAccentSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              r.s('emoji') ?? '⭐',
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.s('title') ?? '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  yearly
                      ? '$dateText · каждый год${years > 0 ? ' · $years ${plural(years, 'год', 'года', 'лет')}' : ''}'
                      : dateText,
                  style: TextStyle(color: kInkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: days == 0 ? kAccentDeep : kField,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: days == 0 ? kAccentDeep : kBorder),
            ),
            child: Text(
              days == null ? 'прошла' : untilText(days),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: days == 0 ? Colors.white : kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showImportantSheet(
  BuildContext context,
  AppStore store, {
  Rec? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ImportantSheet(store: store, existing: existing),
  );
}

class _ImportantSheet extends StatefulWidget {
  final AppStore store;
  final Rec? existing;
  const _ImportantSheet({required this.store, this.existing});

  @override
  State<_ImportantSheet> createState() => _ImportantSheetState();
}

class _ImportantSheetState extends State<_ImportantSheet> {
  late final TextEditingController _title;
  late DateTime _date;
  late bool _yearly;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.s('title') ?? '');
    _date = e?.s('date') != null
        ? parseYmd(e!.s('date')!)
        : dateOnly(DateTime.now());
    _yearly = e?.b('yearly') ?? true;
    _emoji = e?.s('emoji') ?? '🎂';
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final t = _title.text.trim();
    if (t.isEmpty) {
      toast(context, 'Введите название');
      return;
    }
    widget.store.upsert('important', {
      'title': t,
      'date': ymd(_date),
      'yearly': _yearly,
      'emoji': _emoji,
    }, id: widget.existing?.id);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Новая важная дата' : 'Важная дата',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Например: День рождения Ани',
              ),
            ),
            const SectionTitle('Значок'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _emojis)
                  PressScale(
                    scale: 0.9,
                    onTap: () => setState(() => _emoji = e),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? kAccentSoft : kField,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: e == _emoji ? kAccentDeep : kBorder,
                          width: e == _emoji ? 1.6 : 1,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
            const SectionTitle('Дата'),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await pickDate(context, _date);
                    if (d != null) setState(() => _date = dateOnly(d));
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    '${_date.day}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                  ),
                ),
              ),
            ),
            SwitchRow(
              value: _yearly,
              onChanged: (v) => setState(() => _yearly = v),
              title: const Text('Повторять каждый год'),
              subtitle: const Text('Для дней рождения и годовщин'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Сохранить'),
                ),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () async {
                    if (await confirm(
                      context,
                      'Удалить дату?',
                      yes: 'Удалить',
                    )) {
                      widget.store.remove(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    }
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
      ),
    );
  }
}
