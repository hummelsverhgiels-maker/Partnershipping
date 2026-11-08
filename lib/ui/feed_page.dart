import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../models.dart';
import '../services/media_service.dart';
import 'common.dart';
import 'media_viewer.dart';
import 'media_widgets.dart';
import 'theme.dart';

/// Лента: общая «стена» пары. Тексты, фото и видео, лайки и комментарии.
class FeedPage extends StatelessWidget {
  final AppStore store;
  const FeedPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final posts = store.posts;
    return Scaffold(
      appBar: AppBar(title: const Text('Лента')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => showPostSheet(context, store),
        icon: const Icon(Icons.edit_rounded),
        label: const Text(
          'Опубликовать',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: posts.isEmpty
          ? const Center(
              child: EmptyHint(
                'Здесь будут ваши общие фото, видео и заметки.\nПоделитесь первым моментом!',
                icon: Icons.photo_library_outlined,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: posts.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PostCard(store: store, post: posts[i]),
              ),
            ),
    );
  }
}

String whenText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final hm =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  final dd = DateTime(d.year, d.month, d.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(dd).inDays;
  if (diff == 0) return 'сегодня, $hm';
  if (diff == 1) return 'вчера, $hm';
  return '${d.day}.${d.month.toString().padLeft(2, '0')}.${d.year}, $hm';
}

Rec _viewerRec(Map m) => Rec(
  id: 'feed-${m['path']}',
  kind: 'message',
  data: {'path': m['path'], 'type': m['type'], 'name': m['name']},
  updatedAt: DateTime.now(),
);

class PostCard extends StatelessWidget {
  final AppStore store;
  final Rec post;
  const PostCard({super.key, required this.store, required this.post});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final author = s.memberById(post.s('from'));
    final mine = post.s('from') == s.session?.memberId;
    final media = ((post.data['media'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final text = post.s('text') ?? '';
    final likes = ((post.data['likes'] as Map?) ?? const {}).length;
    final liked = s.postLikedByMe(post);
    final comments = s.commentsByPost[post.id]?.length ?? 0;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color(author?.color ?? kMemberColors.first),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  (author?.name ?? '?').characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: kOnPastel,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author?.name ?? 'Кто-то',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      whenText(post.i('ts') ?? 0),
                      style: TextStyle(fontSize: 12, color: kInkSoft),
                    ),
                  ],
                ),
              ),
              if (mine)
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: () async {
                    if (await confirm(
                      context,
                      'Удалить публикацию?',
                      yes: 'Удалить',
                    )) {
                      s.deletePost(post);
                    }
                  },
                  icon: Icon(Icons.delete_outline, color: kInkSoft),
                ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(fontSize: 16, height: 1.35)),
          ],
          if (media.isNotEmpty) ...[
            const SizedBox(height: 10),
            _mediaGrid(context, media),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              _action(
                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                likes > 0 ? '$likes' : 'Нравится',
                liked ? const Color(0xFFE5677F) : kInkSoft,
                () => s.toggleLike(post),
              ),
              const SizedBox(width: 6),
              _action(
                Icons.chat_bubble_outline_rounded,
                comments > 0 ? '$comments' : 'Комментарий',
                kInkSoft,
                () => showCommentsSheet(context, s, post),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return PressScale(
      scale: 0.9,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Map m) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            MediaViewer(store: store, message: _viewerRec(m), star: false),
      ),
    );
  }

  Widget _tile(BuildContext context, Map m, {double? height}) {
    if (m['type'] == 'video') {
      return GestureDetector(
        onTap: () => _open(context, m),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
          ),
        ),
      );
    }
    return ImageThumb(
      path: m['path'] as String,
      height: height,
      onTap: () => _open(context, m),
    );
  }

  Widget _mediaGrid(BuildContext context, List<Map<String, dynamic>> media) {
    if (media.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: _tile(context, media.first, height: 260),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [for (final m in media.take(6)) _tile(context, m)],
    );
  }
}

// ------------------------------------------------------------- комментарии
Future<void> showCommentsSheet(BuildContext context, AppStore store, Rec post) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CommentsSheet(store: store, post: post),
  );
}

class _CommentsSheet extends StatefulWidget {
  final AppStore store;
  final Rec post;
  const _CommentsSheet({required this.store, required this.post});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    widget.store.addComment(widget.post.id, _ctrl.text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final list =
            widget.store.commentsByPost[widget.post.id] ?? const <Rec>[];
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Комментарии',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Пока никто не комментировал',
                            style: TextStyle(color: kInkSoft),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final c in list)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _comment(c),
                              ),
                          ],
                        ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Написать комментарий',
                        ),
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
                          onPressed: _send,
                          child: const Icon(Icons.send_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _comment(Rec c) {
    final s = widget.store;
    final a = s.memberById(c.s('from'));
    final mine = c.s('from') == s.session?.memberId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ColorDot(a?.color ?? kMemberColors.first, size: 12),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    a?.name ?? 'Кто-то',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    whenText(c.i('ts') ?? 0),
                    style: TextStyle(fontSize: 11.5, color: kInkSoft),
                  ),
                ],
              ),
              Text(c.s('text') ?? '', style: const TextStyle(height: 1.3)),
            ],
          ),
        ),
        if (mine)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => s.remove(c.id),
            icon: Icon(Icons.close_rounded, size: 18, color: kInkSoft),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------- новая публикация
Future<void> showPostSheet(BuildContext context, AppStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PostSheet(store: store),
  );
}

class _PostSheet extends StatefulWidget {
  final AppStore store;
  const _PostSheet({required this.store});

  @override
  State<_PostSheet> createState() => _PostSheetState();
}

class _PostSheetState extends State<_PostSheet> {
  final _text = TextEditingController();
  final List<PickedMedia> _media = [];
  bool _busy = false;
  String _status = '';

  AppStore get s => widget.store;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<PickedMedia?> Function() pick) async {
    if (s.isLocal) {
      toast(context, 'Фото и видео работают только в паре с сервером');
      return;
    }
    if (_media.length >= 6) {
      toast(context, 'Не больше 6 файлов в одной публикации');
      return;
    }
    try {
      final m = await pick();
      if (m != null && mounted) setState(() => _media.add(m));
    } catch (e) {
      if (mounted) toast(context, e is String ? e : 'Не удалось выбрать файл');
    }
  }

  Future<void> _publish() async {
    if (_text.text.trim().isEmpty && _media.isEmpty) {
      toast(context, 'Напишите что-нибудь или добавьте фото');
      return;
    }
    setState(() => _busy = true);
    try {
      final uploaded = <Map<String, dynamic>>[];
      for (var i = 0; i < _media.length; i++) {
        setState(() => _status = 'Загружаю ${i + 1} из ${_media.length}…');
        final m = _media[i];
        final path = await MediaService.upload(s.session!, m);
        uploaded.add({
          'type': m.type,
          'path': path,
          'name': m.name,
          'size': m.bytes.length,
        });
      }
      s.createPost(_text.text, uploaded);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Не удалось опубликовать'),
            content: SingleChildScrollView(
              child: SelectableText(
                '${e is String ? e : Backend.explain(e)}\n\nПодробности: $e',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Понятно'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '';
        });
      }
    }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Новая публикация',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              enabled: !_busy,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Чем хотите поделиться?',
              ),
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < _media.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 84,
                                height: 84,
                                child: _media[i].type == 'image'
                                    ? Image.memory(
                                        _media[i].bytes,
                                        fit: BoxFit.cover,
                                        cacheWidth: 200,
                                      )
                                    : const ColoredBox(
                                        color: Colors.black87,
                                        child: Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white,
                                          size: 34,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: PressScale(
                                scale: 0.85,
                                onTap: _busy
                                    ? null
                                    : () => setState(() => _media.removeAt(i)),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Фото'),
                  onPressed: _busy
                      ? null
                      : () => _pick(
                          () => MediaService.pickImage(ImageSource.gallery),
                        ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Камера'),
                  onPressed: _busy
                      ? null
                      : () => _pick(
                          () => MediaService.pickImage(ImageSource.camera),
                        ),
                ),
                ActionChip(
                  avatar: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Видео'),
                  onPressed: _busy
                      ? null
                      : () => _pick(
                          () => MediaService.pickVideo(ImageSource.gallery),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: FilledButton(
                  onPressed: _busy ? null : _publish,
                  child: _busy
                      ? Text(_status.isEmpty ? 'Публикую…' : _status)
                      : const Text('Опубликовать'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
