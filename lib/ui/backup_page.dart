import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../util.dart';
import 'common.dart';
import 'extras_common.dart';
import 'theme.dart';

/// Резервная копия: сохранить все данные файлом и восстановить из него.
/// Фото и видео в копию не входят (они лежат на сервере), входят ссылки на них.
class BackupPage extends StatefulWidget {
  final AppStore store;
  const BackupPage({super.key, required this.store});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  AppStore get s => widget.store;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final text = s.exportBackup();
      final bytes = Uint8List.fromList(utf8.encode(text));
      final name = 'vv-backup-${ymd(DateTime.now())}.json';
      final saved = await FilePicker.saveFile(
        fileName: name,
        bytes: bytes,
        mimeType: 'application/json',
        dialogTitle: 'Сохранить резервную копию',
      );
      if (!mounted) return;
      if (saved != null || kIsWeb) {
        toast(context, 'Копия сохранена: $name');
      }
    } catch (e) {
      if (mounted) await showFail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: s.exportBackup()));
    if (mounted) {
      toast(
        context,
        'Копия скопирована. Вставьте её, например, в «Заметки» телефона',
      );
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final f = await FilePicker.pickFile();
      if (f == null) return;
      final data = await f.xFile.readAsBytes();
      if (!mounted) return;
      final ok = await confirm(
        context,
        'Восстановить данные из файла «${f.name}»? Более новые записи на этом телефоне не пострадают.',
        yes: 'Восстановить',
      );
      if (!ok) return;
      final n = s.importBackup(utf8.decode(data));
      if (mounted) {
        toast(
          context,
          n == 0
              ? 'Нечего восстанавливать: всё уже есть'
              : 'Восстановлено записей: $n',
        );
      }
    } catch (e) {
      if (mounted) await showFail(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Резервная копия')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Все ваши записи (график, списки, чат, лента, Оливка, бюджет…) — '
                    'одним файлом. Фото и видео остаются на сервере, в копию попадают только '
                    'ссылки на них.',
                    style: TextStyle(color: kInkSoft, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Сейчас записей: ${s.exportBackup().split('"kind"').length - 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: FilledButton.icon(
                  key: const ValueKey('backup-save'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Сохранить копию в файл'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Скопировать как текст'),
                ),
              ),
            ),
            const SectionTitle('ВОССТАНОВЛЕНИЕ'),
            SizedBox(
              width: double.infinity,
              child: Bouncy(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _restore,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Восстановить из файла'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
