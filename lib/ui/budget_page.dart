import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../logic/stats.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

const _cats = <(String, String, String)>[
  ('food', 'Продукты', '🛒'),
  ('home', 'Дом', '🏠'),
  ('cafe', 'Кафе', '☕'),
  ('transport', 'Транспорт', '🚌'),
  ('fun', 'Развлечения', '🎬'),
  ('health', 'Здоровье', '💊'),
  ('gifts', 'Подарки', '🎁'),
  ('dog', 'Оливка', '🐶'),
  ('other', 'Другое', '🧾'),
];

(String, String, String) _cat(String? id) =>
    _cats.firstWhere((c) => c.$1 == id, orElse: () => _cats.last);

double? parseAmount(String t) {
  final v = double.tryParse(
    t.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
  );
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

/// Общий бюджет: траты по месяцам и копилки на цели.
class BudgetPage extends StatefulWidget {
  final AppStore store;
  const BudgetPage({super.key, required this.store});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late DateTime _month;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
  }

  void _shift(int d) =>
      setState(() => _month = DateTime(_month.year, _month.month + d));

  bool _inMonth(Rec r) {
    final d = r.s('date');
    return d != null &&
        d.startsWith(
          '${_month.year.toString().padLeft(4, '0')}-${_month.month.toString().padLeft(2, '0')}',
        );
  }

  double _amount(Rec r) => (r.data['amount'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final list = s.expenses.where(_inMonth).toList();
        final total = list.fold<double>(0, (a, r) => a + _amount(r));
        final byCat = <String, double>{};
        final byMember = <String, double>{};
        for (final r in list) {
          byCat[r.s('cat') ?? 'other'] =
              (byCat[r.s('cat') ?? 'other'] ?? 0) + _amount(r);
          final by = r.s('by') ?? '';
          byMember[by] = (byMember[by] ?? 0) + _amount(r);
        }
        final cats = byCat.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Бюджет'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => showExpenseSheet(context, s, month: _month),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Трата',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            children: [
              Row(
                children: [
                  _arrow(Icons.chevron_left_rounded, () => _shift(-1)),
                  Expanded(
                    child: Center(
                      child: Text(
                        monthTitle(_month),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  _arrow(Icons.chevron_right_rounded, () => _shift(1)),
                ],
              ),
              const SizedBox(height: 12),
              SoftCard(
                color: kWarnBg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Потрачено за месяц',
                      style: TextStyle(color: kInkSoft),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fmtMoney(total),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (byMember.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          for (final e in byMember.entries)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ColorDot(
                                  s.memberById(e.key)?.color ??
                                      kMemberColors.first,
                                  size: 11,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${s.memberById(e.key)?.name ?? 'Кто-то'}: ${fmtMoney(e.value)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (cats.isNotEmpty) ...[
                const SectionTitle('НА ЧТО УШЛИ ДЕНЬГИ'),
                SoftCard(
                  child: Column(
                    children: [
                      for (final e in cats) ...[
                        _catBar(e.key, e.value, total),
                        if (e != cats.last) const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
              SectionTitle('ТРАТЫ (${list.length})'),
              if (list.isEmpty)
                const EmptyHint(
                  'В этом месяце трат пока нет.\nНажмите «Трата», чтобы добавить.',
                  icon: Icons.receipt_long_outlined,
                ),
              for (final r in list) ...[
                _expenseTile(r),
                const SizedBox(height: 8),
              ],
              SectionTitle(
                'КОПИЛКИ',
                trailing: TextButton.icon(
                  onPressed: () => showGoalSheet(context, s),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Цель'),
                ),
              ),
              if (s.goals.isEmpty)
                const EmptyHint(
                  'Копите вместе на отпуск, технику или мечту.',
                  icon: Icons.savings_outlined,
                ),
              for (final g in s.goals) ...[
                _goalCard(g),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => PressScale(
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
      child: Icon(icon, size: 28),
    ),
  );

  Widget _catBar(String id, double value, double total) {
    final c = _cat(id);
    final share = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Text(c.$3, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.$2,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              fmtMoney(value),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            color: kField,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: share,
              child: Container(color: kAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _expenseTile(Rec r) {
    final c = _cat(r.s('cat'));
    final by = s.memberById(r.s('by'));
    final d = r.s('date') != null ? parseYmd(r.s('date')!) : null;
    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF7B7B7),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: kOnPastel),
      ),
      onDismissed: (_) => s.remove(r.id),
      child: SoftCard(
        onTap: () => showExpenseSheet(context, s, existing: r, month: _month),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kAccentSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(c.$3, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (r.s('title') ?? '').isEmpty ? c.$2 : r.s('title')!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${d != null ? '${d.day}.${d.month.toString().padLeft(2, '0')}' : ''}'
                    '${by != null ? ' · ${by.name}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: kInkSoft),
                  ),
                ],
              ),
            ),
            Text(
              fmtMoney(_amount(r)),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalCard(Rec g) {
    final target = (g.data['target'] as num?)?.toDouble() ?? 0;
    final saved = (g.data['saved'] as num?)?.toDouble() ?? 0;
    final p = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final done = target > 0 && saved >= target;
    return SoftCard(
      onTap: () => showGoalSheet(context, s, existing: g),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(done ? '🎉' : '🐷', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.s('title') ?? '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(p * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: kAccentDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 12,
              color: kField,
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                widthFactor: p,
                child: Container(
                  color: done ? const Color(0xFF7DBE8B) : kAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${fmtMoney(saved)} из ${fmtMoney(target)}',
                  style: TextStyle(color: kInkSoft, fontSize: 13),
                ),
              ),
              Bouncy(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _topUp(g),
                  child: const Text('Пополнить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _topUp(Rec g) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('В копилку «${g.s('title')}»'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]')),
          ],
          decoration: const InputDecoration(hintText: 'Сумма', suffixText: '₽'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    final v = parseAmount(ctrl.text);
    ctrl.dispose();
    if (ok == true && v != null && v != 0) {
      final saved = (g.data['saved'] as num?)?.toDouble() ?? 0;
      final next = (saved + v) < 0 ? 0.0 : saved + v;
      s.upsert('goal', {...g.data, 'saved': next}, id: g.id);
    }
  }
}

// ------------------------------------------------------------ окна ввода
Future<void> showExpenseSheet(
  BuildContext context,
  AppStore store, {
  Rec? existing,
  DateTime? month,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _ExpenseSheet(store: store, existing: existing, month: month),
  );
}

class _ExpenseSheet extends StatefulWidget {
  final AppStore store;
  final Rec? existing;
  final DateTime? month;
  const _ExpenseSheet({required this.store, this.existing, this.month});

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late String _cat;
  late DateTime _date;
  late String _by;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.s('title') ?? '');
    final a = (e?.data['amount'] as num?)?.toDouble();
    _amount = TextEditingController(
      text: a == null
          ? ''
          : (a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString()),
    );
    _cat = e?.s('cat') ?? 'food';
    final now = dateOnly(DateTime.now());
    final m = widget.month;
    _date = e?.s('date') != null
        ? parseYmd(e!.s('date')!)
        : (m != null && (m.year != now.year || m.month != now.month)
              ? DateTime(m.year, m.month, 1)
              : now);
    _by = e?.s('by') ?? widget.store.session!.memberId;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      toast(context, 'Введите сумму');
      return;
    }
    widget.store.upsert('expense', {
      'title': _title.text.trim(),
      'amount': v,
      'cat': _cat,
      'date': ymd(_date),
      'by': _by,
    }, id: widget.existing?.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
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
              widget.existing == null ? 'Новая трата' : 'Трата',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amount,
              autofocus: widget.existing == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              decoration: const InputDecoration(hintText: '0', suffixText: '₽'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Что купили (необязательно)',
              ),
            ),
            const SectionTitle('Категория'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _cats)
                  ChoiceChip(
                    label: Text('${c.$3} ${c.$2}'),
                    selected: _cat == c.$1,
                    onSelected: (_) => setState(() => _cat = c.$1),
                  ),
              ],
            ),
            if (s.orderedMembers.length > 1) ...[
              const SectionTitle('Кто платил'),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in s.orderedMembers)
                    ChoiceChip(
                      avatar: ColorDot(m.color),
                      label: Text(m.name),
                      selected: _by == m.id,
                      onSelected: (_) => setState(() => _by = m.id),
                    ),
                ],
              ),
            ],
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
                  onPressed: () {
                    s.remove(widget.existing!.id);
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
      ),
    );
  }
}

Future<void> showGoalSheet(
  BuildContext context,
  AppStore store, {
  Rec? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GoalSheet(store: store, existing: existing),
  );
}

class _GoalSheet extends StatefulWidget {
  final AppStore store;
  final Rec? existing;
  const _GoalSheet({required this.store, this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _title;
  late final TextEditingController _target;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.s('title') ?? '');
    final t = (e?.data['target'] as num?)?.toDouble();
    _target = TextEditingController(
      text: t == null
          ? ''
          : (t == t.roundToDouble() ? t.toStringAsFixed(0) : t.toString()),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  void _save() {
    final t = _title.text.trim();
    final v = parseAmount(_target.text);
    if (t.isEmpty) {
      toast(context, 'Введите название цели');
      return;
    }
    if (v == null || v <= 0) {
      toast(context, 'Введите, сколько нужно накопить');
      return;
    }
    widget.store.upsert('goal', {
      ...?widget.existing?.data,
      'title': t,
      'target': v,
      'saved': (widget.existing?.data['saved'] as num?)?.toDouble() ?? 0,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existing == null ? 'Новая цель' : 'Цель',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _title,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'На что копим'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              hintText: 'Сколько нужно',
              suffixText: '₽',
            ),
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
                  if (await confirm(
                    context,
                    'Удалить цель вместе с накоплениями?',
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
    );
  }
}
