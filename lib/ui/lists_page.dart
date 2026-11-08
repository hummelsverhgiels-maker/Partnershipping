import 'package:flutter/material.dart';

import '../data/store.dart';
import 'shopping_page.dart';
import 'theme.dart';
import 'todos_page.dart';
import 'wishes_view.dart';

/// Вкладка «Списки»: покупки, дела и идеи «сходить вместе».
class ListsPage extends StatefulWidget {
  final AppStore store;
  const ListsPage({super.key, required this.store});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final Widget body;
    switch (_seg) {
      case 1:
        body = TodosPage(
          store: s,
          embedded: true,
          key: const ValueKey('todos'),
        );
      case 2:
        body = WishesView(store: s, key: const ValueKey('wishes'));
      default:
        body = ShoppingPage(
          store: s,
          embedded: true,
          key: const ValueKey('shop'),
        );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Списки')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: kAccentSoft,
                  foregroundColor: kInkSoft,
                  selectedForegroundColor: kInk,
                ),
                segments: const [
                  ButtonSegment(value: 0, label: Text('Покупки')),
                  ButtonSegment(value: 1, label: Text('Дела')),
                  ButtonSegment(value: 2, label: Text('Вместе')),
                ],
                selected: {_seg},
                onSelectionChanged: (v) => setState(() => _seg = v.first),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
