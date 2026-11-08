import 'dart:math';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models.dart';
import 'common.dart';
import 'theme.dart';

const _wishCats = <(String, String, String)>[
  ('movie', 'Кино', '🎬'),
  ('food', 'Еда', '🍽️'),
  ('place', 'Места', '📍'),
  ('trip', 'Поездки', '✈️'),
  ('other', 'Другое', '✨'),
];

(String, String, String) _wc(String? id) =>
    _wishCats.firstWhere((c) => c.$1 == id, orElse: () => _wishCats.last);

/// «Сходить вместе»: общий список идей (фильмы, места, еда, поездки).
class WishesView extends StatefulWidget {
  final AppStore store;
  const WishesView({super.key, required this.store});

  @override
  State<WishesView> createState() => _WishesViewState();
}

class _WishesViewState extends State<WishesView> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _cat = 'movie';
  String? _filter; // null = все категории
  bool _showDone = false;

  AppStore get s => widget.store;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    s.upsert('wish', {'title': t, 'cat': _cat, 'done': false});
    _ctrl.clear();
    _focus.requestFocus();
  }

  Future<void> _random(List<Rec> pool) async {
    if (pool.isEmpty) {
      toast(context, 'Сначала добавьте пару идей');
      return;
    }
    final pick = pool[Random().nextInt(pool.length)];
    final c = _wc(pick.s('cat'));
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Судьба решила 🎲'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.$3, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 8),
            Text(
              pick.s('title') ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Другое'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Идём!'),
          ),
        ],
      ),
    );
    if (go == true) {
      s.upsert('wish', {...pick.data, 'done': true}, id: pick.id);
    } else if (go == false && mounted) {
      await _random(
        pool.length > 1 ? pool.where((r) => r.id != pick.id).toList() : pool,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = s.wishes;
    bool match(Rec r) => _filter == null || r.s('cat') == _filter;
    final todo = all.where((r) => !r.b('done') && match(r)).toList();
    final done = all.where((r) => r.b('done') && match(r)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'Куда сходим? Что посмотрим?',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                height: 56,
                child: Bouncy(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: _add,
                    child: const Icon(Icons.add_rounded, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final c in _wishCats)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${c.$3} ${c.$2}'),
                    selected: _cat == c.$1,
                    onSelected: (_) => setState(() => _cat = c.$1),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('Все', null),
                      for (final c in _wishCats) _filterChip(c.$3, c.$1),
                    ],
                  ),
                ),
              ),
              Bouncy(
                child: TextButton.icon(
                  onPressed: () => _random(todo),
                  icon: const Text('🎲', style: TextStyle(fontSize: 18)),
                  label: const Text('Выбрать'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: all.isEmpty
              ? const Center(
                  child: EmptyHint(
                    'Здесь будут идеи, куда сходить вместе:\nфильмы, кафе, места, поездки.',
                    icon: Icons.favorite_border_rounded,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final r in todo) _item(r),
                    if (done.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: PressScale(
                          onTap: () => setState(() => _showDone = !_showDone),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Text(
                                  'СХОДИЛИ (${done.length})',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: kInkSoft,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showDone
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: kInkSoft,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_showDone)
                      for (final r in done) _item(r),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PressScale(
        scale: 0.92,
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? kAccentSoft : kField,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? kAccentDeep : kBorder),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: kInk),
          ),
        ),
      ),
    );
  }

  Widget _item(Rec r) {
    final c = _wc(r.s('cat'));
    final done = r.b('done');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () => s.upsert('wish', {...r.data, 'done': !done}, id: r.id),
          child: Row(
            children: [
              Text(c.$3, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: done ? kInkSoft : kInk,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                  child: Text(r.s('title') ?? ''),
                ),
              ),
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done ? const Color(0xFF7DBE8B) : kInkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
