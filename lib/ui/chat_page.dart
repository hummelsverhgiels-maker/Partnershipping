import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models.dart';
import 'common.dart';
import 'theme.dart';

class ChatPage extends StatefulWidget {
  final AppStore store;
  final bool active; // эта вкладка сейчас открыта
  const ChatPage({super.key, required this.store, required this.active});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  AppStore get s => widget.store;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text;
    if (t.trim().isEmpty) return;
    s.sendMessage(t);
    _ctrl.clear();
    _focus.requestFocus();
  }

  String _hm(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  bool _sameDay(int a, int b) {
    final x = DateTime.fromMillisecondsSinceEpoch(a);
    final y = DateTime.fromMillisecondsSinceEpoch(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active && s.unreadChat > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.markChatSeen());
    }
    final msgs = s.messages;
    final partner = s.partner;
    final meId = s.session?.memberId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Чат'),
            if (partner != null) ...[
              const SizedBox(width: 10),
              ColorDot(partner.color, size: 12),
              const SizedBox(width: 6),
              Text(
                partner.name,
                style: const TextStyle(fontSize: 16, color: kInkSoft),
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          if (partner == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SoftCard(
                color: Color(0xFFFFF1D6),
                child: Text(
                  'Партнёр ещё не подключился. Сообщения увидит, когда зайдёт в пару.',
                ),
              ),
            ),
          Expanded(
            child: msgs.isEmpty
                ? const Center(
                    child: EmptyHint(
                      'Сообщений пока нет.\nНапишите первое!',
                      icon: Icons.chat_bubble_outline,
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final idx = msgs.length - 1 - i;
                      final m = msgs[idx];
                      final ts = m.i('ts') ?? 0;
                      final mine = m.updatedBy == meId;
                      final showDay =
                          idx == 0 || !_sameDay(ts, msgs[idx - 1].i('ts') ?? 0);
                      final author = s.memberById(m.updatedBy);
                      return Column(
                        children: [
                          if (showDay)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                longDate(
                                  DateTime.fromMillisecondsSinceEpoch(ts),
                                ),
                                style: const TextStyle(
                                  color: kInkSoft,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          _bubble(m, mine, author, ts),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Сообщение'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(54, 54),
                      ),
                      onPressed: _send,
                      child: const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Rec m, bool mine, Member? author, int ts) {
    final base = Color(author?.color ?? kMemberColors.first);
    final width = MediaQuery.of(context).size.width * 0.78;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine
            ? () async {
                if (await confirm(
                  context,
                  'Удалить сообщение?',
                  yes: 'Удалить',
                )) {
                  s.remove(m.id);
                }
              }
            : null,
        child: Container(
          constraints: BoxConstraints(maxWidth: width.clamp(200, 460)),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
          decoration: BoxDecoration(
            color: mine ? base : base.withValues(alpha: 0.35),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  m.s('text') ?? '',
                  style: const TextStyle(fontSize: 16, color: kInk),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _hm(ts),
                style: const TextStyle(fontSize: 11, color: kInkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
