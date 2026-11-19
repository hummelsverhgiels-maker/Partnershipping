import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models.dart';
import '../services/media_service.dart';
import '../util.dart';
import 'common.dart';
import 'extras_common.dart';
import 'media_viewer.dart';
import 'media_widgets.dart';
import 'theme.dart';

const _kRed = Color(0xFFD9534F);

// ================================================================ поза дня

/// «Поза дня»: фото, как спит Оливка, с оценкой «пузом кверху».
class DogPosesPage extends StatefulWidget {
  final AppStore store;
  const DogPosesPage({super.key, required this.store});

  @override
  State<DogPosesPage> createState() => _DogPosesPageState();
}

class _DogPosesPageState extends State<DogPosesPage> {
  bool _busy = false;
  AppStore get s => widget.store;

  Future<void> _add() async {
    if (s.isLocal) {
      toast(context, 'Фото работают только в паре с сервером');
      return;
    }
    final src = await askSource(context);
    if (src == null || !mounted) return;
    try {
      final m = await MediaService.pickImage(src);
      if (m == null || !mounted) return;
      final info = await _askRate();
      if (info == null) return;
      setState(() => _busy = true);
      final path = await MediaService.upload(s.session!, m, folder: 'dog');
      s.upsert('pose', {
        'path': path,
        'name': m.name,
        'date': ymd(DateTime.now()),
        'caption': info.$1,
        'rate': info.$2,
        'by': s.session!.memberId,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      if (mounted) await showFail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Подпись и оценка пузика (1–5).
  Future<(String, int)?> _askRate({String caption = '', int rate = 3}) {
    final c = TextEditingController(text: caption);
    var r = rate;
    return showDialog<(String, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Поза дня'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: c,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Подпись (необязательно)',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Пузик кверху, по 5-балльной шкале',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 1; i <= 5; i++)
                    ChoiceChip(
                      label: Text('$i'),
                      selected: r == i,
                      onSelected: (_) => set(() => r = i),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, (c.text.trim(), r)),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(Rec r) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ImageThumb(
                  path: r.s('path')!,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MediaViewer(
                          store: s,
                          message: viewerRec(
                            r.s('path')!,
                            'image',
                            r.s('name') ?? 'Поза',
                          ),
                          star: false,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${dmy(r.s('date'))} · ${whoName(s, r.s('by'))} · пузик ${r.i('rate') ?? 3}/5',
                style: TextStyle(color: kInkSoft),
              ),
              if ((r.s('caption') ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    r.s('caption')!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final v = await _askRate(
                        caption: r.s('caption') ?? '',
                        rate: r.i('rate') ?? 3,
                      );
                      if (v != null) {
                        s.upsert('pose', {
                          ...r.data,
                          'caption': v.$1,
                          'rate': v.$2,
                        }, id: r.id);
                      }
                    },
                    child: const Text('Изменить'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final ok = await confirm(
                        ctx,
                        'Удалить это фото?',
                        yes: 'Удалить',
                      );
                      if (!ok || !ctx.mounted) return;
                      s.remove(r.id);
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      'Удалить',
                      style: TextStyle(color: _kRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final all = s.kindList('pose').reversed.toList();
        final now = DateTime.now();
        final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        Rec? best;
        for (final r in all) {
          if (!(r.s('date') ?? '').startsWith(month)) continue;
          if (best == null || (r.i('rate') ?? 0) > (best.i('rate') ?? 0)) {
            best = r;
          }
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Поза дня')),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(Icons.add_a_photo_rounded),
            label: const Text('Фото'),
          ),
          body: all.isEmpty
              ? const EmptyHint(
                  'Снимайте, как спит Оливка.\nВ конце месяца выберем лучшую позу 🏆',
                  icon: Icons.pets,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    if (best != null) ...[
                      SoftCard(
                        color: kAccentSoft,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 84,
                              height: 84,
                              child: ImageThumb(
                                path: best.s('path')!,
                                width: 84,
                                height: 84,
                                onTap: () => _open(best!),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '🏆 Лучшая поза месяца',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${(best.s('caption') ?? '').isEmpty ? dmy(best.s('date')) : best.s('caption')}'
                                    ' · пузик ${best.i('rate') ?? 3}/5',
                                    style: TextStyle(color: kInkSoft),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final r in all)
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              ImageThumb(
                                path: r.s('path')!,
                                onTap: () => _open(r),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${dmy(r.s('date')).substring(0, dmy(r.s('date')).lastIndexOf('.'))} · ${r.i('rate') ?? 3}/5',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}
