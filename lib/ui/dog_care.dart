import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/dog.dart';
import '../models.dart';
import '../util.dart';
import 'budget_page.dart' show parseAmount;
import 'common.dart';
import 'dog_today.dart';
import 'theme.dart';

const _kRed = Color(0xFFD9534F);

/// Небольшая кнопка внутри карточки (обычные — высокие, на всю ширину).
final _compact = FilledButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
);

String _dmy(String? d) {
  if (d == null || d.isEmpty) return '—';
  final x = parseYmd(d);
  return '${x.day}.${x.month.toString().padLeft(2, '0')}.${x.year}';
}

// =================================================================== здоровье

/// 3) «Здоровье»: прививки, обработки, груминг (с напоминаниями) и вес.
class DogHealthPage extends StatelessWidget {
  final AppStore store;
  const DogHealthPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final care = [...s.dogCare]
          ..sort((a, b) {
            final na = careNext(a.s('last'), a.i('every') ?? 0);
            final nb = careNext(b.s('last'), b.i('every') ?? 0);
            if (na == null && nb == null) return 0;
            if (na == null) return 1;
            if (nb == null) return -1;
            return na.compareTo(nb);
          });
        return Scaffold(
          appBar: AppBar(title: Text('Здоровье · ${s.dogName}')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => showDogCareSheet(context, s),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Процедура'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              const SectionTitle('ПРИВИВКИ И ОБРАБОТКИ'),
              if (care.isEmpty)
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добавьте прививки, глистогонку, обработку от клещей — '
                        'приложение посчитает, когда следующий раз, и напомнит.',
                        style: TextStyle(color: kInkSoft, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Bouncy(
                        child: FilledButton.tonal(
                          onPressed: () {
                            for (final p in kDogCarePresets.take(4)) {
                              s.upsert('dogcare', {
                                'title': p.title,
                                'emoji': p.emoji,
                                'every': p.every,
                              });
                            }
                          },
                          child: const Text('Добавить основные'),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final r in care) ...[
                _careTile(context, s, r, today),
                const SizedBox(height: 8),
              ],
              const SectionTitle('ВЕС'),
              _weightCard(context, s),
            ],
          ),
        );
      },
    );
  }

  Widget _careTile(BuildContext context, AppStore s, Rec r, DateTime today) {
    final next = careNext(r.s('last'), r.i('every') ?? 0);
    final d = next == null ? null : daysBetween(today, next);
    final color = d == null
        ? kInkSoft
        : (d < 0 ? _kRed : (d <= 3 ? const Color(0xFFE0A100) : kInkSoft));
    return SoftCard(
      onTap: () => showDogCareSheet(context, s, existing: r),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          dogEmojiBox(r.s('emoji') ?? '💉'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.s('title') ?? 'Процедура',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  next == null
                      ? 'Ещё не отмечали · раз в ${r.i('every') ?? 0} дн.'
                      : 'Следующий раз ${dueText(d!)} (${_dmy(ymd(next))})',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: d != null && d <= 3
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (r.s('last') != null)
                  Text(
                    'Последний раз: ${_dmy(r.s('last'))}'
                    '${r.s('by') != null ? ' · ${dogWho(s, r.s('by'))}' : ''}',
                    style: TextStyle(color: kInkSoft, fontSize: 12),
                  ),
              ],
            ),
          ),
          Bouncy(
            child: FilledButton.tonal(
              style: _compact,
              onPressed: () {
                HapticFeedback.lightImpact();
                s.markCareDone(r);
                toast(context, 'Отмечено: ${r.s('title')}');
              },
              child: const Text('Сделано'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _weightCard(BuildContext context, AppStore s) {
    final ws = s.dogWeights;
    final last = ws.isEmpty ? null : ws.last;
    final prev = ws.length < 2 ? null : ws[ws.length - 2];
    String fmt(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    String? diff;
    if (last != null && prev != null) {
      final dv = last.d('kg')! - prev.d('kg')!;
      if (dv.abs() >= 0.05) {
        diff =
            '${dv > 0 ? '+' : '−'}${fmt(dv.abs())} кг с ${_dmy(prev.s('date'))}';
      }
    }
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                last == null ? '—' : '${fmt(last.d('kg')!)} кг',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              if (diff != null)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(diff, style: TextStyle(color: kInkSoft)),
                  ),
                ),
            ],
          ),
          if (ws.length >= 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 90,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeightChart(
                  [for (final w in ws.skip(max(0, ws.length - 12))) w.d('kg')!],
                  kAccentDeep,
                  kBorder,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Bouncy(
                child: FilledButton.tonalIcon(
                  style: _compact,
                  onPressed: () => _addWeight(context, s),
                  icon: const Icon(Icons.monitor_weight_outlined),
                  label: const Text('Записать вес'),
                ),
              ),
              if (ws.isNotEmpty)
                TextButton(
                  onPressed: () => _weightHistory(context, s),
                  child: const Text('История'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addWeight(BuildContext context, AppStore s) async {
    final c = TextEditingController();
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Вес ${s.dogName} сегодня'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(hintText: '0', suffixText: 'кг'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, parseAmount(c.text)),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v == null || v <= 0 || v > 150) return;
    s.addDogWeight(v, DateTime.now());
  }

  Future<void> _weightHistory(BuildContext context, AppStore s) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: s,
        builder: (ctx, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final w in s.dogWeights.reversed)
              ListTile(
                title: Text('${w.d('kg')} кг'),
                subtitle: Text(_dmy(w.s('date'))),
                trailing: IconButton(
                  tooltip: 'Удалить',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => s.remove(w.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeightChart extends CustomPainter {
  final List<double> values;
  final Color line;
  final Color grid;
  _WeightChart(this.values, this.line, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(min);
    final hi = values.reduce(max);
    final span = (hi - lo).abs() < 0.1 ? 1.0 : hi - lo;
    Offset at(int i) => Offset(
      6 + (size.width - 12) * i / (values.length - 1),
      8 + (size.height - 16) * (1 - (values[i] - lo) / span),
    );
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      g,
    );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(at(i), i == values.length - 1 ? 5 : 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChart old) =>
      old.values.join(',') != values.join(',') || old.line != line;
}

Future<void> showDogCareSheet(
  BuildContext context,
  AppStore store, {
  Rec? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DogItemSheet(store: store, existing: existing, care: true),
);

Future<void> showDogSupplySheet(
  BuildContext context,
  AppStore store, {
  Rec? existing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _DogItemSheet(store: store, existing: existing, care: false),
);

/// Общая форма: процедура (care) или запас.
class _DogItemSheet extends StatefulWidget {
  final AppStore store;
  final Rec? existing;
  final bool care;
  const _DogItemSheet({required this.store, this.existing, required this.care});

  @override
  State<_DogItemSheet> createState() => _DogItemSheetState();
}

class _DogItemSheetState extends State<_DogItemSheet> {
  late final TextEditingController _title;
  late final TextEditingController _days;
  late String _emoji;
  DateTime? _date;

  bool get care => widget.care;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.s('title') ?? '');
    _days = TextEditingController(
      text: '${e?.i(care ? 'every' : 'lasts') ?? (care ? 90 : 30)}',
    );
    _emoji = e?.s('emoji') ?? (care ? '💉' : '🥣');
    final d = e?.s(care ? 'last' : 'bought');
    _date = d == null ? (care ? null : dateOnly(DateTime.now())) : parseYmd(d);
  }

  @override
  void dispose() {
    _title.dispose();
    _days.dispose();
    super.dispose();
  }

  void _save() {
    final t = _title.text.trim();
    final n = int.tryParse(_days.text.trim());
    if (t.isEmpty) {
      toast(context, 'Введите название');
      return;
    }
    if (n == null || n <= 0 || n > 3650) {
      toast(
        context,
        care
            ? 'Укажите, раз во сколько дней'
            : 'Укажите, на сколько дней хватает',
      );
      return;
    }
    final base = {...?widget.existing?.data};
    if (care) {
      final hist = <String>[
        ...((base['history'] as List?) ?? const []).map((e) => '$e'),
      ];
      if (_date != null && !hist.contains(ymd(_date!))) {
        hist
          ..add(ymd(_date!))
          ..sort();
      }
      widget.store.upsert('dogcare', {
        ...base,
        'title': t,
        'emoji': _emoji,
        'every': n,
        'last': _date == null ? null : ymd(_date!),
        'history': hist,
      }, id: widget.existing?.id);
    } else {
      widget.store.upsert('dogsupply', {
        ...base,
        'title': t,
        'emoji': _emoji,
        'lasts': n,
        'bought': ymd(_date ?? DateTime.now()),
      }, id: widget.existing?.id);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final presets = care
        ? [for (final p in kDogCarePresets) (p.emoji, p.title, p.every)]
        : [for (final p in kDogSupplyPresets) (p.emoji, p.title, p.lasts)];
    final emojis = care
        ? const [
            '💉',
            '🦠',
            '🪱',
            '🕷️',
            '🩺',
            '✂️',
            '💅',
            '🛁',
            '🦷',
            '👂',
            '💊',
            '🐾',
          ]
        : const ['🥣', '🥫', '🦴', '🛍️', '💊', '🧴', '🧸', '🦮', '🛏️', '🐾'];
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
              widget.existing != null
                  ? (care ? 'Процедура' : 'Запас')
                  : (care ? 'Новая процедура' : 'Новый запас'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            if (widget.existing == null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in presets)
                    ActionChip(
                      avatar: Text(p.$1),
                      label: Text(p.$2),
                      onPressed: () => setState(() {
                        _emoji = p.$1;
                        _title.text = p.$2;
                        _days.text = '${p.$3}';
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: care
                    ? 'Например, «Глистогонка»'
                    : 'Например, «Сухой корм»',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: care ? 'Раз в  ' : 'Хватает на  ',
                suffixText: 'дней',
              ),
            ),
            const SectionTitle('Значок'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in emojis)
                  ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 18)),
                    selected: _emoji == e,
                    onSelected: (_) => setState(() => _emoji = e),
                  ),
              ],
            ),
            SectionTitle(care ? 'Последний раз делали' : 'Когда купили'),
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
                        if (d != null) setState(() => _date = dateOnly(d));
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _date == null
                            ? 'Не помню / ещё не было'
                            : _dmy(ymd(_date!)),
                      ),
                    ),
                  ),
                ),
                if (care && _date != null)
                  IconButton(
                    tooltip: 'Сбросить',
                    onPressed: () => setState(() => _date = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
                    final ok = await confirm(
                      context,
                      'Удалить «${_title.text}»?',
                      yes: 'Удалить',
                    );
                    if (!ok || !context.mounted) return;
                    widget.store.remove(widget.existing!.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Удалить', style: TextStyle(color: _kRed)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================================================================== запасы

/// 4) «Запасы»: корм, лакомства, пакеты — на сколько ещё хватит.
class DogSuppliesPage extends StatelessWidget {
  final AppStore store;
  const DogSuppliesPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final list = [...s.dogSupplies]
          ..sort((a, b) {
            int left(Rec r) => r.s('bought') == null
                ? 9999
                : supplyLeft(r.s('bought')!, r.i('lasts') ?? 30, today);
            return left(a).compareTo(left(b));
          });
        return Scaffold(
          appBar: AppBar(title: const Text('Запасы для собаки')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => showDogSupplySheet(context, s),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Запас'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              Text(
                'Отмечайте покупку — приложение посчитает, когда закончится, '
                'и подскажет заранее. «В покупки» добавит в общий список.',
                style: TextStyle(color: kInkSoft, height: 1.35),
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Пока пусто',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Bouncy(
                        child: FilledButton.tonal(
                          onPressed: () {
                            for (final p in kDogSupplyPresets.take(4)) {
                              s.upsert('dogsupply', {
                                'title': p.title,
                                'emoji': p.emoji,
                                'lasts': p.lasts,
                                'bought': ymd(today),
                              });
                            }
                          },
                          child: const Text('Добавить корм, лакомства, пакеты'),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final r in list) ...[
                _tile(context, s, r, today),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, AppStore s, Rec r, DateTime today) {
    final lasts = r.i('lasts') ?? 30;
    final left = r.s('bought') == null
        ? lasts
        : supplyLeft(r.s('bought')!, lasts, today);
    final frac = (left / lasts).clamp(0.0, 1.0);
    final low = left <= 3;
    return SoftCard(
      onTap: () => showDogSupplySheet(context, s, existing: r),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              dogEmojiBox(r.s('emoji') ?? '🥣', size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.s('title') ?? 'Запас',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      left <= 0
                          ? 'Закончилось — пора купить'
                          : 'Хватит ещё на $left ${plural(left, 'день', 'дня', 'дней')}',
                      style: TextStyle(
                        color: low ? _kRed : kInkSoft,
                        fontWeight: low ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Куплено ${_dmy(r.s('bought'))} · хватает на $lasts дн.',
                      style: TextStyle(color: kInkSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              backgroundColor: kField,
              color: low ? _kRed : kAccentDeep,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  final added = s.supplyToShopping(r);
                  toast(
                    context,
                    added ? 'Добавлено в покупки 🛒' : 'Уже есть в покупках',
                  );
                },
                child: const Text('В покупки'),
              ),
              const SizedBox(width: 4),
              Bouncy(
                child: FilledButton.tonal(
                  style: _compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    s.markSupplyBought(r);
                    toast(context, 'Отлично! Считаем заново');
                  },
                  child: const Text('Купили'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
