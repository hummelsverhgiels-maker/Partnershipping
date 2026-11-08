import 'package:flutter/material.dart';

import '../data/store.dart';
import '../logic/schedule.dart';
import '../util.dart';
import 'common.dart';
import 'shift_sheet.dart';
import 'sheets.dart';
import 'theme.dart';

/// Экран одного дня: смены, выплаты, события, дела.
class DayPage extends StatelessWidget {
  final AppStore store;
  final DateTime date;
  const DayPage({super.key, required this.store, required this.date});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final key = ymd(date);
        final events = store.events.where((e) => e.s('date') == key).toList();
        final todos = store.todos.where((t) => t.s('date') == key).toList();
        final pays = store.schedule.paymentsInRange(date, date);
        return Scaffold(
          appBar: AppBar(
            title: const Text('День'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _hero(),
              const SectionTitle('СМЕНЫ'),
              for (final m in store.orderedMembers) ...[
                _shiftRow(context, m.id),
                const SizedBox(height: 10),
              ],
              if (pays.isNotEmpty) ...[
                const SectionTitle('ЗАРПЛАТА И АВАНС'),
                for (final p in pays) ...[
                  _payRow(p),
                  const SizedBox(height: 10),
                ],
              ],
              SectionTitle(
                'СОБЫТИЯ',
                trailing: TextButton.icon(
                  onPressed: () => showEventSheet(context, store, date: date),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ),
              if (events.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Событий нет', style: TextStyle(color: kInkSoft)),
                ),
              for (final e in events) ...[
                SoftCard(
                  onTap: () => showEventSheet(context, store, event: e),
                  child: Row(
                    children: [
                      const Text('📌', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.s('time') != null ? '${e.s('time')}  ' : ''}${e.s('title')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (e.s('note') != null)
                              Text(
                                e.s('note')!,
                                style: const TextStyle(color: kInkSoft),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SectionTitle(
                'ДЕЛА',
                trailing: TextButton.icon(
                  onPressed: () => showTodoSheet(context, store, date: date),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить'),
                ),
              ),
              if (todos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'Дел на этот день нет',
                    style: TextStyle(color: kInkSoft),
                  ),
                ),
              for (final t in todos) ...[
                TodoTile(store: store, todo: t),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Крупная шапка с датой.
  Widget _hero() {
    final isToday = dateOnly(date) == dateOnly(DateTime.now());
    final full = longDate(date);
    final parts = full.split(', ');
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE0D2), Color(0xFFFBD3E0)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parts.first,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kInkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.length > 1 ? parts.sublist(1).join(', ') : full,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: kInk,
                  ),
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Сегодня',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: kAccentDeep,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shiftRow(BuildContext context, String memberId) {
    final m = store.memberById(memberId)!;
    final shift = store.schedule.shiftOf(memberId, date);
    final explicitOff = store.schedule.explicitOff(memberId, date);
    final mine = memberId == store.session?.memberId;

    String main;
    String? sub;
    if (shift != null) {
      main = shift.label;
      if (shift.overnight) sub = '🌙 до следующего дня';
    } else if (explicitOff) {
      main = 'Выходной';
    } else {
      main = 'Выходной';
      sub = 'смены не заданы';
    }
    return SoftCard(
      onTap: () => showShiftSheet(context, store, [date], memberId: memberId),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 44,
            decoration: BoxDecoration(
              color: Color(m.color),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mine ? 'Я (${m.name})' : m.name,
                  style: const TextStyle(color: kInkSoft, fontSize: 13),
                ),
                Text(
                  main,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: const TextStyle(color: kInkSoft, fontSize: 13),
                  ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, color: kInkSoft),
        ],
      ),
    );
  }

  Widget _payRow(PayItem p) {
    final m = store.memberById(p.memberId);
    return SoftCard(
      color: const Color(0xFFFFF1D6),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.label} · ${m?.name ?? ''}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (p.shifted)
                  Text(
                    'перенесено с ${p.nominal.day}.${p.nominal.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: kInkSoft, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
