import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models.dart';
import 'common.dart';
import 'theme.dart';

class ShoppingPage extends StatefulWidget {
  final AppStore store;
  const ShoppingPage({super.key, required this.store});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

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
    s.upsert('shopping', {'title': t, 'bought': false});
    _ctrl.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final todo = s.shopping.where((r) => !r.b('bought')).toList();
    final bought = s.shopping.where((r) => r.b('bought')).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Покупки'),
        actions: [
          if (bought.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                if (await confirm(
                  context,
                  'Удалить ${bought.length} купленных из списка?',
                  yes: 'Очистить',
                )) {
                  for (final r in bought) {
                    s.remove(r.id);
                  }
                }
              },
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Очистить'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: 'Что купить?'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(56, 56),
                    ),
                    onPressed: _add,
                    child: const Icon(Icons.add, size: 30),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: s.shopping.isEmpty
                ? const Center(
                    child: EmptyHint(
                      'Список пуст.\nДобавьте первую покупку.',
                      icon: Icons.shopping_basket_outlined,
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final r in todo) _item(r),
                      if (bought.isNotEmpty)
                        SectionTitle('КУПЛЕНО (${bought.length})'),
                      for (final r in bought) _item(r),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _item(Rec r) {
    final bought = r.b('bought');
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
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(Icons.delete_outline, color: kInk),
        ),
        onDismissed: (_) => s.remove(r.id),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          onTap: () =>
              s.upsert('shopping', {...r.data, 'bought': !bought}, id: r.id),
          child: Row(
            children: [
              Checkbox(
                value: bought,
                shape: const CircleBorder(),
                side: const BorderSide(color: kInkSoft, width: 2),
                onChanged: (v) => s.upsert('shopping', {
                  ...r.data,
                  'bought': v ?? false,
                }, id: r.id),
              ),
              Expanded(
                child: Text(
                  r.s('title') ?? '',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: bought ? TextDecoration.lineThrough : null,
                    color: bought ? kInkSoft : kInk,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Удалить',
                onPressed: () => s.remove(r.id),
                icon: const Icon(Icons.close, color: kInkSoft, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
