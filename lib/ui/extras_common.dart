import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../models.dart';
import '../util.dart';
import 'common.dart';

String dmy(String? d) {
  if (d == null || d.isEmpty) return '—';
  final x = parseYmd(d);
  return '${x.day}.${x.month.toString().padLeft(2, '0')}.${x.year}';
}

String whoName(AppStore s, String? id) {
  if (id == null) return '';
  if (id == s.session?.memberId) return 'Я';
  return nameOf(s.memberById(id));
}

/// Выбор источника (камера или галерея).
Future<ImageSource?> askSource(BuildContext context, {bool video = false}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              video ? Icons.videocam_rounded : Icons.photo_camera_rounded,
            ),
            title: Text(video ? 'Снять видео' : 'Сделать снимок'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Показать понятную ошибку.
Future<void> showFail(BuildContext context, Object e) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Не получилось'),
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

/// Запись, которую понимает полноэкранный просмотр.
Rec viewerRec(String path, String type, String name) => Rec(
  id: 'view-$path',
  kind: 'message',
  data: {'path': path, 'type': type, 'name': name},
  updatedAt: DateTime.now(),
);

/// Простое окно «текст + необязательная вторая строка».
Future<(String, String)?> askTwo(
  BuildContext context, {
  required String title,
  required String hint1,
  String? hint2,
  String v1 = '',
  String v2 = '',
}) async {
  final a = TextEditingController(text: v1);
  final b = TextEditingController(text: v2);
  final r = await showDialog<(String, String)>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: hint1),
            ),
            if (hint2 != null) ...[
              const SizedBox(height: 10),
              TextField(
                controller: b,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: hint2),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, (a.text.trim(), b.text.trim())),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
  a.dispose();
  b.dispose();
  return r;
}
