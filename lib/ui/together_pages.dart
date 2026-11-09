import 'dart:math';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/important.dart';
import '../logic/together.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'extras_common.dart';
import 'theme.dart';

const _kRed = Color(0xFFD9534F);

// ============================================================ мы вместе

/// Карточка «Мы вместе» (на «Сегодня»).
class TogetherCard extends StatelessWidget {
  final AppStore store;
  const TogetherCard({super.key, required this.store});

  static Future<void> pickSince(BuildContext context, AppStore s) async {
    final cur = s.togetherSince;
    final d = await pickDate(
      context,
      cur == null ? DateTime.now() : parseYmd(cur),
    );
    if (d != null) s.setTogetherSince(ymd(dateOnly(d)));
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    final since = s.togetherSince;
    final today = dateOnly(DateTime.now());
    if (since == null) {
      return SoftCard(
        key: const ValueKey('together-card'),
        onTap: () => pickSince(context, s),
        child: Row(
          children: [
            const Text('💞', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Укажите, когда вы начали встречаться — посчитаем дни вместе',
                style: TextStyle(color: kInkSoft, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }
    final sd = parseYmd(since);
    final n = daysTogether(sd, today);
    final mile = nextMilestone(sd, today);
    return SoftCard(
      key: const ValueKey('together-card'),
      onTap: () => pickSince(context, s),
      color: kAccentSoft,
      child: Row(
        children: [
          const Text('💞', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n ${plural(n, 'день', 'дня', 'дней')} вместе',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  togetherText(sd, today),
                  style: TextStyle(color: kInkSoft),
                ),
                if (mile != null)
                  Text(
                    'Дальше: ${mile.$2} — ${untilText(daysUntil(mile.$1, today))}',
                    style: TextStyle(color: kInkSoft, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================ благодарности

/// «Банка благодарностей».
class GratitudePage extends StatelessWidget {
  final AppStore store;
  const GratitudePage({super.key, required this.store});

  Future<void> _add(BuildContext context) async {
    final r = await askTwo(
      context,
      title: 'Спасибо за…',
      hint1: 'За что благодарите?',
      hint2: 'Подробнее (необязательно)',
    );
    if (r == null || r.$1.isEmpty) return;
    store.upsert('thanks', {
      'title': r.$1,
      'text': r.$2,
      'by': store.session?.memberId,
      'date': ymd(DateTime.now()),
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _random(BuildContext context, List<Rec> all) {
    final r = all[Random().nextInt(all.length)];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🫙 Из банки'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Спасибо за ${r.s('title')}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if ((r.s('text') ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(r.s('text')!),
              ),
            const SizedBox(height: 8),
            Text(
              '${whoName(store, r.s('by'))}, ${dmy(r.s('date'))}',
              style: TextStyle(color: kInkSoft),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.kindList('thanks').reversed.toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Банка благодарностей'),
            actions: [
              if (all.isNotEmpty)
                IconButton(
                  tooltip: 'Достать записку',
                  icon: const Icon(Icons.casino_outlined),
                  onPressed: () => _random(context, all),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _add(context),
            icon: const Icon(Icons.favorite_rounded),
            label: const Text('Спасибо'),
          ),
          body: all.isEmpty
              ? const EmptyHint(
                  'Записывайте, за что вы благодарны друг другу.\nВ плохой день можно достать записку 💛',
                  icon: Icons.volunteer_activism_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    Text(
                      'В банке: ${all.length}',
                      style: TextStyle(color: kInkSoft),
                    ),
                    const SizedBox(height: 8),
                    for (final r in all) ...[
                      SoftCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💛', style: TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Спасибо за ${r.s('title')}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if ((r.s('text') ?? '').isNotEmpty)
                                    Text(
                                      r.s('text')!,
                                      style: TextStyle(color: kInkSoft),
                                    ),
                                  Text(
                                    '${whoName(store, r.s('by'))} · ${dmy(r.s('date'))}',
                                    style: TextStyle(
                                      color: kInkSoft,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (r.s('by') == store.session?.memberId)
                              IconButton(
                                tooltip: 'Удалить',
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: kInkSoft,
                                ),
                                onPressed: () => store.remove(r.id),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// ============================================================ идеи свиданий

class DateIdeasPage extends StatefulWidget {
  final AppStore store;
  const DateIdeasPage({super.key, required this.store});

  @override
  State<DateIdeasPage> createState() => _DateIdeasPageState();
}

class _DateIdeasPageState extends State<DateIdeasPage> {
  (String, String)? _pick;
  final _rnd = Random();
  AppStore get s => widget.store;

  /// Идеи, которые ещё не «были»: встроенные и свои.
  List<(String, String)> _pool() {
    final done = {
      for (final r in s.kindList('dateidea'))
        if (r.b('done')) r.s('title') ?? '',
    };
    final own = [
      for (final r in s.kindList('dateidea'))
        if (!r.b('done') && r.b('custom'))
          (r.s('emoji') ?? '✨', r.s('title') ?? ''),
    ];
    return [
      for (final i in kDateIdeas)
        if (!done.contains(i.$2)) i,
      ...own,
    ];
  }

  void _roll() {
    final p = _pool();
    setState(() => _pick = p.isEmpty ? null : p[_rnd.nextInt(p.length)]);
  }

  void _went((String, String) i) {
    final ex = s
        .kindList('dateidea')
        .where((r) => r.s('title') == i.$2)
        .toList();
    s.upsert('dateidea', {
      'title': i.$2,
      'emoji': i.$1,
      'done': true,
      'custom': ex.isNotEmpty && ex.first.b('custom'),
      'date': ymd(DateTime.now()),
      'ts': ex.isNotEmpty
          ? ex.first.i('ts')
          : DateTime.now().millisecondsSinceEpoch,
    }, id: ex.isEmpty ? null : ex.first.id);
    setState(() => _pick = null);
    toast(context, 'Записали в «Были» 💞');
  }

  Future<void> _addOwn() async {
    final r = await askTwo(
      context,
      title: 'Своя идея',
      hint1: 'Что придумали?',
    );
    if (r == null || r.$1.isEmpty) return;
    s.upsert('dateidea', {
      'title': r.$1,
      'emoji': '✨',
      'done': false,
      'custom': true,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final done = s
            .kindList('dateidea')
            .where((r) => r.b('done'))
            .toList()
            .reversed
            .toList();
        final own = s
            .kindList('dateidea')
            .where((r) => !r.b('done') && r.b('custom'))
            .toList();
        final pick = _pick;
        return Scaffold(
          appBar: AppBar(title: const Text('Идеи для свиданий')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _addOwn,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Своя идея'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              SoftCard(
                color: kAccentSoft,
                child: Column(
                  children: [
                    if (pick == null)
                      Text(
                        _pool().isEmpty
                            ? 'Вы попробовали все идеи! Добавьте свои 🎉'
                            : 'Не знаете, чем заняться?',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else ...[
                      Text(pick.$1, style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 4),
                      Text(
                        pick.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        Bouncy(
                          child: FilledButton.icon(
                            key: const ValueKey('idea-roll'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: _pool().isEmpty ? null : _roll,
                            icon: const Icon(Icons.casino_rounded),
                            label: Text(pick == null ? 'Подсказать' : 'Другая'),
                          ),
                        ),
                        if (pick != null)
                          Bouncy(
                            child: FilledButton.tonalIcon(
                              key: const ValueKey('idea-went'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: () => _went(pick),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Сходили'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (own.isNotEmpty) ...[
                const SectionTitle('НАШИ ИДЕИ'),
                for (final r in own)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                      child: Row(
                        children: [
                          Text(
                            r.s('emoji') ?? '✨',
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.s('title') ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Сходили',
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                            onPressed: () => _went((
                              r.s('emoji') ?? '✨',
                              r.s('title') ?? '',
                            )),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            icon: Icon(Icons.close_rounded, color: kInkSoft),
                            onPressed: () => s.remove(r.id),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              SectionTitle('МЫ УЖЕ БЫЛИ (${done.length})'),
              if (done.isEmpty)
                Text(
                  'Пока пусто. Нажмите «Сходили», когда попробуете идею.',
                  style: TextStyle(color: kInkSoft),
                ),
              for (final r in done)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                    child: Row(
                      children: [
                        Text(
                          r.s('emoji') ?? '✨',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.s('title') ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                dmy(r.s('date')),
                                style: TextStyle(color: kInkSoft, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Вернуть в идеи',
                          icon: Icon(Icons.undo_rounded, color: kInkSoft),
                          onPressed: () => s.remove(r.id),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================ дни рождения

/// Дни рождения друзей и родных, с копилкой идей подарков.
class BirthdaysPage extends StatelessWidget {
  final AppStore store;
  const BirthdaysPage({super.key, required this.store});

  Future<void> _edit(BuildContext context, {Rec? r}) async {
    final name = TextEditingController(text: r?.s('name') ?? '');
    final rel = TextEditingController(text: r?.s('rel') ?? '');
    var date = r?.s('date');
    final gifts = <Map<String, dynamic>>[
      for (final g in (r?.data['gifts'] as List? ?? const []))
        Map<String, dynamic>.from(g as Map),
    ];
    final giftCtl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r == null ? 'Новый человек' : 'День рождения',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  autofocus: r == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Имя'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: rel,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Кто это (мама, друг…)',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await pickDate(
                      ctx,
                      date == null ? DateTime(2000, 1, 1) : parseYmd(date!),
                    );
                    if (d != null) set(() => date = ymd(dateOnly(d)));
                  },
                  icon: const Icon(Icons.cake_outlined),
                  label: Text(date == null ? 'Дата рождения' : dmy(date)),
                ),
                const SectionTitle('ИДЕИ ПОДАРКОВ'),
                for (var i = 0; i < gifts.length; i++)
                  Row(
                    children: [
                      Checkbox(
                        value: gifts[i]['done'] == true,
                        onChanged: (v) =>
                            set(() => gifts[i]['done'] = v ?? false),
                      ),
                      Expanded(
                        child: Text(
                          '${gifts[i]['t']}',
                          style: TextStyle(
                            decoration: gifts[i]['done'] == true
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => set(() => gifts.removeAt(i)),
                      ),
                    ],
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: giftCtl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Что подарить?',
                        ),
                        onSubmitted: (v) {
                          if (v.trim().isEmpty) return;
                          set(() => gifts.add({'t': v.trim(), 'done': false}));
                          giftCtl.clear();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      onPressed: () {
                        if (giftCtl.text.trim().isEmpty) return;
                        set(
                          () => gifts.add({
                            't': giftCtl.text.trim(),
                            'done': false,
                          }),
                        );
                        giftCtl.clear();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Bouncy(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Сохранить'),
                    ),
                  ),
                ),
                if (r != null)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        store.remove(r.id);
                        Navigator.pop(ctx, false);
                      },
                      child: const Text(
                        'Удалить',
                        style: TextStyle(color: _kRed),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final n = name.text.trim();
    final rl = rel.text.trim();
    final pending = giftCtl.text.trim();
    name.dispose();
    rel.dispose();
    giftCtl.dispose();
    if (ok != true) return;
    if (n.isEmpty || date == null) {
      if (context.mounted) toast(context, 'Нужны имя и дата рождения');
      return;
    }
    if (pending.isNotEmpty) gifts.add({'t': pending, 'done': false});
    store.upsert('person', {
      ...?r?.data,
      'name': n,
      'rel': rl,
      'date': date,
      'gifts': gifts,
      'ts': r?.i('ts') ?? DateTime.now().millisecondsSinceEpoch,
    }, id: r?.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final today = dateOnly(DateTime.now());
        final items = <(Rec, DateTime)>[
          for (final r in store.kindList('person'))
            if (r.s('date') != null)
              (r, nextOccurrence(parseYmd(r.s('date')!), true, today)!),
        ]..sort((a, b) => a.$2.compareTo(b.$2));
        return Scaffold(
          appBar: AppBar(title: const Text('Дни рождения')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить'),
          ),
          body: items.isEmpty
              ? const EmptyHint(
                  'Друзья и родные: не забудете поздравить и придумаете подарок заранее 🎁',
                  icon: Icons.cake_outlined,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    for (final (r, next) in items) ...[
                      SoftCard(
                        onTap: () => _edit(context, r: r),
                        child: Row(
                          children: [
                            const Text('🎂', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.s('name')}${(r.s('rel') ?? '').isEmpty ? '' : ' · ${r.s('rel')}'}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    '${untilText(daysUntil(next, today))} · исполнится ${yearsAt(parseYmd(r.s('date')!), next)}',
                                    style: TextStyle(
                                      color: daysUntil(next, today) <= 7
                                          ? _kRed
                                          : kInkSoft,
                                      fontWeight: daysUntil(next, today) <= 7
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Builder(
                                    builder: (_) {
                                      final g =
                                          (r.data['gifts'] as List? ?? const [])
                                              .where(
                                                (x) =>
                                                    (x as Map)['done'] != true,
                                              )
                                              .length;
                                      return Text(
                                        g == 0
                                            ? 'Идей подарков пока нет'
                                            : '🎁 Идей подарков: $g',
                                        style: TextStyle(
                                          color: kInkSoft,
                                          fontSize: 12,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
