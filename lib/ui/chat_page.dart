import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../models.dart';
import '../services/media_service.dart';
import 'common.dart';
import 'media_viewer.dart';
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
  final _recorder = VoiceRecorder();

  int _tab = 0; // 0 чат, 1 важное, 2 фото и видео, 3 файлы
  bool _hasText = false;
  bool _recording = false;
  bool _uploading = false;
  int _recSeconds = 0;
  Timer? _recTimer;

  AppStore get s => widget.store;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final h = _ctrl.text.trim().isNotEmpty;
      if (h != _hasText) setState(() => _hasText = h);
    });
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _recorder.dispose();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ отправка
  void _send() {
    final t = _ctrl.text;
    if (t.trim().isEmpty) return;
    s.sendMessage(t);
    _ctrl.clear();
    _focus.requestFocus();
  }

  bool _needPair() {
    if (s.isLocal) {
      toast(
        context,
        'Фото, видео и голосовые работают только в паре с сервером',
      );
      return true;
    }
    return false;
  }

  Future<void> _sendPicked(Future<PickedMedia?> Function() pick) async {
    if (_needPair()) return;
    try {
      final m = await pick();
      if (m == null) return;
      setState(() => _uploading = true);
      final path = await MediaService.upload(s.session!, m);
      s.sendMedia(
        type: m.type,
        path: path,
        name: m.name,
        size: m.bytes.length,
        durationMs: m.durationMs,
      );
    } catch (e) {
      if (mounted) toast(context, e is String ? e : Backend.explain(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _attachMenu() {
    if (_needPair()) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget item(IconData icon, String label, VoidCallback onTap) =>
            ListTile(
              leading: CircleAvatar(
                backgroundColor: kAccentSoft,
                child: Icon(icon, color: kInk),
              ),
              title: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onTap();
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(
                Icons.photo_camera_outlined,
                'Сфотографировать',
                () => _sendPicked(
                  () => MediaService.pickImage(ImageSource.camera),
                ),
              ),
              item(
                Icons.photo_library_outlined,
                'Фото из галереи',
                () => _sendPicked(
                  () => MediaService.pickImage(ImageSource.gallery),
                ),
              ),
              item(
                Icons.videocam_outlined,
                'Видео из галереи',
                () => _sendPicked(
                  () => MediaService.pickVideo(ImageSource.gallery),
                ),
              ),
              item(
                Icons.attach_file,
                'Файл или документ',
                () => _sendPicked(MediaService.pickFile),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------- голос
  Future<void> _startRecording() async {
    if (_needPair()) return;
    try {
      final ok = await _recorder.start();
      if (!ok) {
        if (mounted) {
          toast(context, 'Разрешите доступ к микрофону в настройках');
        }
        return;
      }
      setState(() {
        _recording = true;
        _recSeconds = 0;
      });
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSeconds++);
      });
    } catch (e) {
      if (mounted) toast(context, 'Запись не удалась: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _finishRecording() async {
    _recTimer?.cancel();
    setState(() => _recording = false);
    if (_recSeconds < 1) {
      await _recorder.cancel();
      return;
    }
    await _sendPicked(_recorder.stop);
  }

  // ---------------------------------------------------------- действия
  Future<void> _messageMenu(Rec m) async {
    final mine = s.authorOf(m) == s.session?.memberId;
    final text = m.s('text');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                m.b('important')
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
              ),
              title: Text(
                m.b('important') ? 'Убрать из важного' : 'Отметить важным',
              ),
              onTap: () {
                Navigator.pop(ctx);
                s.toggleImportant(m);
              },
            ),
            if (text != null && text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Скопировать текст'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  toast(context, 'Скопировано');
                },
              ),
            if (m.s('path') != null)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Открыть или скачать'),
                onTap: () {
                  Navigator.pop(ctx);
                  openFileExternally(context, m.s('path')!);
                },
              ),
            if (mine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFD9534F),
                ),
                title: const Text(
                  'Удалить',
                  style: TextStyle(color: Color(0xFFD9534F)),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (await confirm(
                    context,
                    'Удалить сообщение?',
                    yes: 'Удалить',
                  )) {
                    s.deleteMessage(m);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openMedia(Rec m) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MediaViewer(store: s, message: m),
      ),
    );
  }

  // --------------------------------------------------------------- вёрстка
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
    if (widget.active && _tab == 0 && s.unreadChat > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.markChatSeen());
    }
    final partner = s.partner;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: kAccentSoft,
                  foregroundColor: kInk,
                ),
                segments: const [
                  ButtonSegment(value: 0, label: Text('Чат')),
                  ButtonSegment(value: 1, label: Text('Важное')),
                  ButtonSegment(value: 2, label: Text('Фото')),
                  ButtonSegment(value: 3, label: Text('Файлы')),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
            ),
          ),
          if (partner == null && _tab == 0)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SoftCard(
                color: Color(0xFFFFF1D6),
                child: Text(
                  'Партнёр ещё не подключился. Сообщения увидит, когда зайдёт в пару.',
                ),
              ),
            ),
          Expanded(child: _tabBody()),
          if (_tab == 0) _inputBar(),
        ],
      ),
    );
  }

  Widget _tabBody() {
    switch (_tab) {
      case 1:
        return _bubbleList(
          s.messages.where((m) => m.b('important')).toList(),
          empty: 'Здесь будут важные сообщения и файлы.\nУдерживайте сообщение и выберите «Отметить важным».',
          icon: Icons.star_border_rounded,
        );
      case 2:
        return _mediaGrid();
      case 3:
        return _filesList();
      default:
        return _bubbleList(
          s.messages,
          empty: 'Сообщений пока нет.\nНапишите первое!',
          icon: Icons.chat_bubble_outline,
        );
    }
  }

  Widget _bubbleList(
    List<Rec> msgs, {
    required String empty,
    required IconData icon,
  }) {
    if (msgs.isEmpty) {
      return Center(child: EmptyHint(empty, icon: icon));
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: msgs.length,
      itemBuilder: (context, i) {
        final idx = msgs.length - 1 - i;
        final m = msgs[idx];
        final ts = m.i('ts') ?? 0;
        final showDay = idx == 0 || !_sameDay(ts, msgs[idx - 1].i('ts') ?? 0);
        return Column(
          children: [
            if (showDay)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  longDate(DateTime.fromMillisecondsSinceEpoch(ts)),
                  style: const TextStyle(color: kInkSoft, fontSize: 12),
                ),
              ),
            _bubble(m, ts),
          ],
        );
      },
    );
  }

  Widget _bubble(Rec m, int ts) {
    final mine = s.authorOf(m) == s.session?.memberId;
    final author = s.memberById(s.authorOf(m));
    final base = Color(author?.color ?? kMemberColors.first);
    final width = MediaQuery.of(context).size.width * 0.78;
    final type = m.s('type') ?? 'text';
    final text = m.s('text');

    Widget content;
    switch (type) {
      case 'image':
        content = _ImageThumb(
          path: m.s('path')!,
          width: 220,
          height: 220,
          onTap: () => _openMedia(m),
        );
      case 'video':
        content = GestureDetector(
          onTap: () => _openMedia(m),
          child: Container(
            width: 220,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 52,
            ),
          ),
        );
      case 'audio':
        content = VoicePlayer(path: m.s('path')!, durationMs: m.i('dur'));
      case 'file':
        content = GestureDetector(
          onTap: () => openFileExternally(context, m.s('path')!),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file_outlined,
                color: kInk,
                size: 30,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.s('name') ?? 'Файл',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kInk,
                      ),
                    ),
                    Text(
                      fmtSize(m.i('size') ?? 0),
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        content = Text(
          text ?? '',
          style: const TextStyle(fontSize: 16, color: kInk),
        );
    }

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _messageMenu(m),
        child: Container(
          constraints: BoxConstraints(maxWidth: width.clamp(220, 460)),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              content,
              if (type != 'text' && text != null && text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 15, color: kInk),
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.b('important'))
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: Color(0xFFD9A400),
                      ),
                    ),
                  Text(
                    _hm(ts),
                    style: const TextStyle(fontSize: 11, color: kInkSoft),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaGrid() {
    final items = s.messages
        .where((m) => m.s('type') == 'image' || m.s('type') == 'video')
        .toList()
        .reversed
        .toList();
    if (items.isEmpty) {
      return const Center(
        child: EmptyHint(
          'Здесь будут все фото и видео из чата.',
          icon: Icons.photo_library_outlined,
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return Stack(
          fit: StackFit.expand,
          children: [
            if (m.s('type') == 'image')
              _ImageThumb(path: m.s('path')!, onTap: () => _openMedia(m))
            else
              GestureDetector(
                onTap: () => _openMedia(m),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            if (m.b('important'))
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: Color(0xFFFFD36B),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _filesList() {
    final items = s.messages
        .where((m) => m.s('type') == 'file' || m.s('type') == 'audio')
        .toList()
        .reversed
        .toList();
    if (items.isEmpty) {
      return const Center(
        child: EmptyHint(
          'Здесь будут документы и голосовые сообщения.',
          icon: Icons.folder_open_outlined,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final m = items[i];
        final isAudio = m.s('type') == 'audio';
        final author = s.memberById(s.authorOf(m));
        final ts = DateTime.fromMillisecondsSinceEpoch(m.i('ts') ?? 0);
        return SoftCard(
          onTap: isAudio
              ? null
              : () => openFileExternally(context, m.s('path')!),
          child: Row(
            children: [
              if (isAudio)
                VoicePlayer(path: m.s('path')!, durationMs: m.i('dur'))
              else
                const Icon(Icons.insert_drive_file_outlined, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAudio ? 'Голосовое сообщение' : (m.s('name') ?? 'Файл'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${author?.name ?? ''} · ${ts.day}.${ts.month.toString().padLeft(2, '0')} ${_hm(ts.millisecondsSinceEpoch)}'
                      '${isAudio ? '' : ' · ${fmtSize(m.i('size') ?? 0)}'}',
                      style: const TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => s.toggleImportant(m),
                icon: Icon(
                  m.b('important')
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: m.b('important') ? const Color(0xFFD9A400) : kInkSoft,
                ),
              ),
              IconButton(
                onPressed: () => _messageMenu(m),
                icon: const Icon(Icons.more_vert, color: kInkSoft),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _inputBar() {
    if (_recording) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Отмена',
                onPressed: _cancelRecording,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFD9534F),
                ),
              ),
              const Icon(
                Icons.fiber_manual_record,
                color: Color(0xFFD9534F),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Запись… ${fmtDuration(_recSeconds * 1000)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 54,
                height: 54,
                child: Bouncy(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(54, 54),
                    ),
                    onPressed: _finishRecording,
                    child: const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Прикрепить',
              onPressed: _uploading ? null : _attachMenu,
              icon: _uploading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.attach_file_rounded, size: 28),
            ),
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
              child: Bouncy(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(54, 54),
                  ),
                  onPressed: _hasText
                      ? _send
                      : (_uploading ? null : _startRecording),
                  child: Icon(
                    _hasText ? Icons.send_rounded : Icons.mic_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Миниатюра фото (подгружается по временной ссылке).
class _ImageThumb extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final VoidCallback onTap;
  const _ImageThumb({
    required this.path,
    this.width,
    this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: FutureBuilder<String>(
            future: MediaService.url(path),
            builder: (context, snap) {
              if (snap.hasError || (snap.hasData && snap.data!.isEmpty)) {
                return const ColoredBox(
                  color: Color(0xFFF1E6DF),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                );
              }
              if (!snap.hasData) {
                return const ColoredBox(
                  color: Color(0xFFF1E6DF),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return Image.network(
                snap.data!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, st) => const ColoredBox(
                  color: Color(0xFFF1E6DF),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
