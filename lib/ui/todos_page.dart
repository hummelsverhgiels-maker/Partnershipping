import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';
import 'sheets.dart';
import 'theme.dart';

class TodosPage extends StatelessWidget {
  final AppStore store;
  const TodosPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final today = ymd(DateTime.now());
    final open = store.todos.where((t) => !t.b('done')).toList();
    final overdue = open
        .where((t) => t.s('date') != null && t.s('date')!.compareTo(today) < 0)
        .toList();
    final todayList = open.where((t) => t.s('date') == today).toList();
    final soon = open
        .where((t) => t.s('date') != null && t.s('date')!.compareTo(today) > 0)
        .toList()
      ..sort((a, b) => a.s('date')!.compareTo(b.s('date')!));
    final noDate = open.where((t) => t.s('date') == null).toList();
    final done = store.todos.where((t) => t.b('done')).toList()
      ..sort((a, b) =>
          (b.s('doneAt') ?? '').compareTo(a.s('doneAt') ?? ''));

    Widget group(String title, List<Rec> list, {bool showDate = false}) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title),
          for (final t in list) ...[
            TodoTile(store: store, todo: t, showDate: showDate),
            const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Дела')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTodoSheet(context, store),
        backgroundColor: const Color(0xFFE58E70),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Новое дело',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: store.todos.isEmpty
          ? const Center(
              child: EmptyHint('Пока нет общих дел.\nДобавьте первое!',
                  icon: Icons.checklist_rtl))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                group('ПРОСРОЧЕНО', overdue, showDate: true),
                group('СЕГОДНЯ', todayList),
                group('СКОРО', soon, showDate: true),
                group('БЕЗ ДАТЫ', noDate),
                if (done.isNotEmpty)
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text('СДЕЛАНО (${done.length})',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: kInkSoft)),
                      children: [
                        for (final t in done) ...[
                          TodoTile(store: store, todo: t, showDate: true),
                          const SizedBox(height: 8),
                        ],
                        TextButton(
                          onPressed: () async {
                            if (await confirm(
                                context, 'Удалить все сделанные дела?',
                                yes: 'Удалить')) {
                              for (final t in done) {
                                store.remove(t.id);
                              }
                            }
                          },
                          child: const Text('Очистить сделанные'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
