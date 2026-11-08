import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../models.dart';
import '../services/media_service.dart';
import 'common.dart';
import 'media_viewer.dart';
import 'theme.dart';

const _docCats = <(String, String)>[
  ('id', 'Личные'),
  ('bills', 'Квитанции'),
  ('contracts', 'Договоры'),
  ('health', 'Медицина'),
  ('other', 'Другое'),
];

String _catName(String? id) =>
    _docCats.firstWhere((c) => c.$1 == id, orElse: () => _docCats.last).$2;

IconData _iconFor(Rec d) {
  if (d.s('kind') == 'link') {
    final u = (d.s('url') ?? '').toLowerCase();
    return u.contains('drive.google') || u.contains('docs.google')
        ? Icons.add_to_drive_rounded
        : Icons.link_rounded;
  }
  final n = (d.s('name') ?? '').toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
  if (RegExp(r'\.(jpg|jpeg|png|gif|webp|heic)$').hasMatch(n)) {
    return Icons.image_outlined;
  }
  if (RegExp(r'\.(xls|xlsx|csv)$').hasMatch(n)) {
    return Icons.table_chart_outlined;
  }
  if (RegExp(r'\.(zip|rar|7z)$').hasMatch(n)) return Icons.folder_zip_outlined;
  if (RegExp(r'\.(mp3|m4a|wav|ogg)$').hasMatch(n)) {
    return Icons.audiotrack_outlined;
  }
  if (RegExp(r'\.(mp4|mov|avi|mkv)$').hasMatch(n)) return Icons.movie_outlined;
  return Icons.description_outlined;
}

Uri _fixUrl(String raw) {
  final t = raw.trim();
  return Uri.parse(t.contains('://') ? t : 'https://$t');
}

/// Документы: общие файлы пары и ссылки (в том числе на Google Диск).
class DocsPage extends StatefulWidget {
  final AppStore store;
  const DocsPage({super.key, required this.store});

  @override
  State<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends State<DocsPage> {
  final _search = TextEditingController();
  String? _cat; // null = все
  bool _busy = false;

  AppStore get s => widget.store;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _sub(Rec d) {
    final parts = <String>[
      if (d.s('kind') == 'link') 'Ссылка' else fmtSize(d.i('size') ?? 0),
      _catName(d.s('cat')),
      s.memberById(d.s('from'))?.name ?? '',
    ].where((e) => e.isNotEmpty).toList();
    return parts.join(' · ');
  }

  Future<void> _open(Rec d) async {
    if (d.s('kind') == 'link') {
      try {
        await launchUrl(
          _fixUrl(d.s('url') ?? ''),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        if (mounted) toast(context, 'Не удалось открыть ссылку');
      }
    } else if (d.s('path') != null) {
      await openFileExternally(context, d.s('path')!, name: d.s('name'));
    }
  }

  Future<void> _addFile() async {
    if (s.isLocal) {
      toast(context, 'Файлы работают только в паре с сервером');
      return;
    }
    try {
      final m = await MediaService.pickFile();
      if (m == null || !mounted) return;
      final info = await _askInfo(title: m.name, withUrl: false);
      if (info == null) return;
      setState(() => _busy = true);
      final path = await MediaService.upload(s.session!, m, folder: 'docs');
      s.addDocFile(
        title: info.$1.isEmpty ? m.name : info.$1,
        path: path,
        name: m.name,
        size: m.bytes.length,
        cat: info.$3,
      );
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Не удалось загрузить'),
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
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addLink() async {
    final info = await _askInfo(title: '', withUrl: true);
    if (info == null) return;
    if (info.$2.trim().isEmpty) {
      if (mounted) toast(context, 'Вставьте ссылку');
      return;
    }
    s.addDocLink(
      title: info.$1.isEmpty ? info.$2.trim() : info.$1,
      url: info.$2.trim(),
      cat: info.$3,
    );
  }

  /// Название, (ссылка) и категория. Возвращает (название, ссылка, категория).
  Future<(String, String, String)?> _askInfo({
    required String title,
    required bool withUrl,
    String cat = 'other',
  }) {
    final t = TextEditingController(text: title);
    final u = TextEditingController();
    var c = cat;
    return showDialog<(String, String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(withUrl ? 'Добавить ссылку' : 'Новый документ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: t,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Название'),
                ),
                if (withUrl) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: u,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'Ссылка (Google Диск и др.)',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in _docCats)
                      ChoiceChip(
                        label: Text(k.$2),
                        selected: c == k.$1,
                        onSelected: (_) => setState(() => c = k.$1),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (t.text.trim(), u.text, c)),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(Rec d) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                d.b('star') ? Icons.star_rounded : Icons.star_border_rounded,
              ),
              title: Text(d.b('star') ? 'Убрать из избранного' : 'В избранное'),
              onTap: () {
                Navigator.pop(ctx);
                s.updateDoc(d, {'star': !d.b('star')});
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать и сменить категорию'),
              onTap: () async {
                Navigator.pop(ctx);
                final info = await _askInfo(
                  title: d.s('title') ?? '',
                  withUrl: false,
                  cat: d.s('cat') ?? 'other',
                );
                if (info != null) {
                  s.updateDoc(d, {
                    'title': info.$1.isEmpty ? d.s('title') : info.$1,
                    'cat': info.$3,
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(
                d.s('kind') == 'link'
                    ? 'Открыть ссылку'
                    : 'Открыть или скачать',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _open(d);
              },
            ),
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
                  'Удалить «${d.s('title')}»?',
                  yes: 'Удалить',
                )) {
                  s.deleteDoc(d);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list =
        s.docs.where((d) {
          if (_cat != null && d.s('cat') != _cat) return false;
          if (q.isEmpty) return true;
          return (d.s('title') ?? '').toLowerCase().contains(q) ||
              (d.s('name') ?? '').toLowerCase().contains(q);
        }).toList()..sort((a, b) {
          if (a.b('star') != b.b('star')) return a.b('star') ? -1 : 1;
          return (b.i('ts') ?? 0).compareTo(a.i('ts') ?? 0);
        });

    return Scaffold(
      appBar: AppBar(title: const Text('Документы')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _busy
            ? null
            : () => showModalBottomSheet<void>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_file_rounded),
                        title: const Text('Загрузить файл'),
                        subtitle: const Text('PDF, фото, документ (до 50 МБ)'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _addFile();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.add_to_drive_rounded),
                        title: const Text('Добавить ссылку'),
                        subtitle: const Text(
                          'Например, на папку в Google Диске',
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _addLink();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          _busy ? 'Загружаю…' : 'Добавить',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по названию',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('Все', null),
                for (final c in _docCats) _chip(c.$2, c.$1),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: EmptyHint(
                      s.docs.isEmpty
                          ? 'Складывайте сюда важные документы:\nпаспорта, договоры, квитанции.\nМожно добавлять и ссылки на Google Диск.'
                          : 'Ничего не найдено',
                      icon: Icons.folder_open_outlined,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final d = list[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SoftCard(
                          onTap: () => _open(d),
                          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: kAccentSoft,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(_iconFor(d), color: kAccentDeep),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.s('title') ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      _sub(d),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: kInkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (d.b('star'))
                                const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFD9A400),
                                  size: 20,
                                ),
                              IconButton(
                                onPressed: () => _menu(d),
                                icon: Icon(Icons.more_vert, color: kInkSoft),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final sel = _cat == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressScale(
        scale: 0.93,
        onTap: () => setState(() => _cat = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? kAccentSoft : kField,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? kAccentDeep : kBorder,
              width: sel ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: kInk),
          ),
        ),
      ),
    );
  }
}
