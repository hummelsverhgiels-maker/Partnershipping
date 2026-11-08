import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../services/notifier.dart';
import '../services/push_service.dart';
import '../services/scriptable.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  final AppStore store;
  const SettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final me = store.me;
    final partner = store.partner;
    final myId = store.session!.memberId;
    final rules = store.schedule.rules.where((r) => r.memberId == myId).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    final dates =
        store.schedule.payDates.where((r) => r.memberId == myId).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final templates = store.templates
        .where((t) => t.s('memberId') == myId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionTitle('Я'),
          SoftCard(
            onTap: () => _editProfile(context),
            child: Row(
              children: [
                ColorDot(me?.color ?? kMemberColors.first, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    me?.name ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.edit_outlined, color: kInkSoft),
              ],
            ),
          ),
          const SectionTitle('Пара'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (store.isLocal) ...[
                  const Text(
                    'Работа без пары',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Данные хранятся только на этом телефоне. '
                    'Когда сервер синхронизации будет подключён, нажмите «Выйти» и создайте пару.',
                    style: TextStyle(color: kInkSoft),
                  ),
                ] else ...[
                  const Text('Код пары', style: TextStyle(color: kInkSoft)),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.session!.code,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Скопировать',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: store.session!.code),
                          );
                          toast(context, 'Код скопирован');
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (partner != null) ...[
                        ColorDot(partner.color),
                        const SizedBox(width: 8),
                        Text(
                          'Партнёр: ${partner.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ] else
                        const Text(
                          'Партнёр ещё не подключился',
                          style: TextStyle(color: kInkSoft),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _syncStatus(),
                ],
              ],
            ),
          ),
          const SectionTitle('Мои шаблоны смен'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (templates.isEmpty)
                  const Text(
                    'Пока нет шаблонов',
                    style: TextStyle(color: kInkSoft),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in templates)
                      InputChip(
                        label: Text('${t.s('start')}–${t.s('end')}'),
                        onDeleted: () => store.remove(t.id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _addTemplate(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить шаблон'),
                ),
              ],
            ),
          ),
          const SectionTitle('Аванс и зарплата'),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Каждый месяц',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (rules.isEmpty)
                  const Text('Не заданы', style: TextStyle(color: kInkSoft)),
                for (final r in rules)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Text('💰', style: TextStyle(fontSize: 22)),
                    title: Text('${r.label}: ${r.day}-го числа'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => store.remove(r.id),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _addRule(context, myId),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить день выплаты'),
                ),
                const Divider(height: 28),
                const Text(
                  'Разовые даты',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (dates.isEmpty)
                  const Text('Не заданы', style: TextStyle(color: kInkSoft)),
                for (final d in dates)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Text('📅', style: TextStyle(fontSize: 22)),
                    title: Text('${d.label}: ${longDate(parseYmd(d.date))}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => store.remove(d.id),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _addDate(context, myId),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить разовую дату'),
                ),
                const Divider(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: store.shiftPayFor(myId),
                  onChanged: (v) => store.setShiftPay(myId, v),
                  title: const Text('Сдвигать выплату с выходного'),
                  subtitle: const Text(
                    'Если в день ежемесячной выплаты у вас нет смены, она переносится на предыдущий день со сменой.',
                  ),
                ),
              ],
            ),
          ),
          if (!store.isLocal) ...[
            const SectionTitle('Виджет на iPhone (бесплатно)'),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Если приложение стоит на iPhone без виджета, можно сделать виджет '
                    'через бесплатное приложение Scriptable.',
                    style: TextStyle(color: kInkSoft),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. На iPhone поставьте «Scriptable» из App Store.\n'
                    '2. Нажмите кнопку ниже: скрипт скопируется.\n'
                    '3. В Scriptable: «+» → вставьте скрипт → назовите «Выходные».\n'
                    '4. На рабочем столе: долгое нажатие → «+» → Scriptable → '
                    'средний размер → «Добавить». Нажмите на виджет → Script: «Выходные».',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: scriptableScript(
                            code: store.session!.code,
                            memberId: store.session!.memberId,
                          ),
                        ),
                      );
                      toast(
                        context,
                        'Скрипт скопирован. Вставьте его в Scriptable',
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Скопировать скрипт виджета'),
                  ),
                ],
              ),
            ),
          ],
          const SectionTitle('Уведомления'),
          SoftCard(
            child: Column(
              children: [
                if (PushService.active && kIsWeb)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await PushService.requestPermission(store);
                        if (context.mounted) {
                          toast(
                            context,
                            ok ? 'Мгновенные уведомления включены' : 'Не получилось. Разрешите уведомления в настройках iPhone',
                          );
                        }
                      },
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Включить мгновенные уведомления'),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: store.getFlag('notif_pay'),
                  onChanged: (v) async {
                    await store.setFlag('notif_pay', v);
                    if (v) await Notifier.requestPermission();
                  },
                  title: const Text('Напоминать о выплатах'),
                  subtitle: const Text(
                    'За день до аванса или зарплаты, в 9:00',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: store.getFlag('notif_partner'),
                  onChanged: (v) async {
                    await store.setFlag('notif_partner', v);
                    if (v) await Notifier.requestPermission();
                  },
                  title: const Text('Когда партнёр что-то изменил'),
                  subtitle: const Text(
                    'Приходит, пока приложение открыто или недавно было открыто',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () async {
                final ok = await confirm(
                  context,
                  store.isLocal
                      ? 'Удалить все данные на этом телефоне и начать заново?'
                      : 'Выйти из пары на этом телефоне? Данные останутся у пары, вернуться можно по коду.',
                  yes: 'Выйти',
                );
                if (ok) await store.leavePair();
              },
              child: const Text(
                'Выйти из пары',
                style: TextStyle(color: Color(0xFFD9534F)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncStatus() {
    final pending = store.pendingCount;
    final ok = store.online && pending == 0;
    return Row(
      children: [
        Icon(
          ok ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          size: 20,
          color: ok ? const Color(0xFF6DBE8B) : kInkSoft,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ok
                ? 'Синхронизировано'
                : store.online
                ? 'Отправляю изменения: $pending'
                : 'Нет связи с сервером${pending > 0 ? ' · ждёт отправки: $pending' : ''}'
                      '${store.lastError != null ? '\n${store.lastError}' : ''}',
            style: const TextStyle(color: kInkSoft, fontSize: 13),
          ),
        ),
        IconButton(
          tooltip: 'Обновить',
          onPressed: store.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final me = store.me;
    final name = TextEditingController(text: me?.name ?? '');
    var color = me?.color ?? kMemberColors.first;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Моё имя и цвет',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'Имя'),
              ),
              const SizedBox(height: 16),
              ColorPicker(
                selected: color,
                onChanged: (c) => setState(() => color = c),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty) return;
                  store.setMyProfile(name.text.trim(), color);
                  Navigator.pop(ctx);
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
  }

  Future<void> _addTemplate(BuildContext context) async {
    var start = '09:00';
    var end = '21:00';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Новый шаблон смены'),
          content: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final v = await pickTime(ctx, start);
                    if (v != null) setState(() => start = v);
                  },
                  child: Text(start, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('—'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final v = await pickTime(ctx, end);
                    if (v != null) setState(() => end = v);
                  },
                  child: Text(end, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                store.upsert('template', {
                  'memberId': store.session!.memberId,
                  'start': start,
                  'end': end,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addRule(BuildContext context, String myId) async {
    final day = TextEditingController();
    var label = 'Аванс';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('День выплаты каждый месяц'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final l in ['Аванс', 'Зарплата'])
                    ChoiceChip(
                      label: Text(l),
                      selected: label == l,
                      onSelected: (_) => setState(() => label = l),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: day,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Число месяца (1–31)',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(day.text);
                if (n == null || n < 1 || n > 31) return;
                store.upsert('payrule', {
                  'memberId': myId,
                  'day': n,
                  'label': label,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    day.dispose();
  }

  Future<void> _addDate(BuildContext context, String myId) async {
    final d = await pickDate(context, dateOnly(DateTime.now()));
    if (d == null || !context.mounted) return;
    var label = 'Выплата';
    final custom = TextEditingController(text: label);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(longDate(d)),
        content: TextField(
          controller: custom,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              store.upsert('paydate', {
                'memberId': myId,
                'date': ymd(d),
                'label': custom.text.trim().isEmpty
                    ? 'Выплата'
                    : custom.text.trim(),
              });
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    custom.dispose();
  }
}
