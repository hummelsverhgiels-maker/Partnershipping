import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data/backend.dart';
import '../data/store.dart';
import '../data/transfer.dart';
import '../util.dart';
import 'common.dart';
import 'theme.dart';

/// Одна строка проверки.
class _Step {
  final String title;
  bool? ok; // null — ещё идёт
  String detail = '';
  int ms = 0;
  _Step(this.title);
}

/// «Проверка связи»: показывает, какие передачи проходят через сеть,
/// и сама включает передачу частями, если крупные файлы обрываются.
class NetCheckPage extends StatefulWidget {
  final AppStore store;
  const NetCheckPage({super.key, required this.store});

  @override
  State<NetCheckPage> createState() => _NetCheckPageState();
}

class _NetCheckPageState extends State<NetCheckPage> {
  final List<_Step> _steps = [];
  bool _running = false;
  String _summary = '';

  AppStore get s => widget.store;

  String _label(String base) => base == kSupabaseUrl
      ? 'напрямую'
      : (base == kSupabaseProxyUrl ? 'через посредника' : base);

  Future<void> _step(String title, Future<String> Function() body) async {
    final st = _Step(title);
    setState(() => _steps.add(st));
    final sw = Stopwatch()..start();
    try {
      st.detail = await body();
      st.ok = true;
    } catch (e) {
      st.ok = false;
      st.detail = e is StorageRejected
          ? 'отказ сервера ${e.status}'
          : e.toString().split('\n').first;
    }
    st.ms = sw.elapsedMilliseconds;
    if (mounted) setState(() {});
  }

  Uint8List _bytes(int n) {
    final r = Random();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  Future<String> _put(String base, String path, Uint8List data) async {
    final token = await Backend.authToken();
    final r = await Transfer.send(
      'POST',
      Uri.parse('$base/storage/v1/object/chat/$path'),
      headers: {
        'apikey': kSupabaseAnonKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/octet-stream',
        'x-upsert': 'true',
      },
      body: data,
      timeout: const Duration(seconds: 25),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw StorageRejected(r.statusCode, r.body);
    }
    return 'ок';
  }

  Future<String> _signed(String base, String path) async {
    final u = await Backend.signedUrl(path);
    return u.startsWith(Backend.activeUrl)
        ? base + u.substring(Backend.activeUrl.length)
        : u;
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _steps.clear();
      _summary = '';
    });
    final pair = s.session?.pairId;
    final created = <String>[];
    var bigOk = false;
    var chunksOk = false;
    try {
      for (final base in Backend.bases) {
        final where = _label(base);
        await _step('Сервер отвечает ($where)', () async {
          final r = await Transfer.send(
            'GET',
            Uri.parse('$base/auth/v1/health'),
            headers: {'apikey': kSupabaseAnonKey},
            timeout: const Duration(seconds: 15),
          );
          return 'код ${r.statusCode}';
        });
        if (pair == null) continue;
        final id = newId();
        final small = '$pair/diag/$id-small.bin';
        final big = '$pair/diag/$id-big.bin';
        created.addAll([small, big]);
        await _step(
          'Отправка 2 КБ ($where)',
          () => _put(base, small, _bytes(2 * 1024)),
        );
        final bigData = _bytes(300 * 1024);
        await _step('Отправка 300 КБ целиком ($where)', () async {
          final r = await _put(base, big, bigData);
          bigOk = true;
          return r;
        });
        await _step('Отправка 300 КБ частями ($where)', () async {
          final p = await Transfer.uploadChunked(
            '$pair/diag/$id-chunks.bin',
            bigData,
            bases: [base],
          );
          created.addAll(Transfer.allObjectNames(p));
          chunksOk = true;
          return '${Transfer.allObjectNames(p).length} частей';
        });
        await _step('Скачивание 300 КБ целиком ($where)', () async {
          final u = await _signed(base, big);
          final r = await Transfer.send(
            'GET',
            Uri.parse(u),
            timeout: const Duration(seconds: 20),
          );
          if (r.statusCode != 200) throw 'код ${r.statusCode}';
          return '${(r.bodyBytes.length / 1024).round()} КБ';
        });
        await _step('Скачивание 300 КБ частями ($where)', () async {
          final u = await _signed(base, big);
          final b = await Transfer.downloadRanged(u);
          return '${(b.length / 1024).round()} КБ';
        });
      }
    } finally {
      if (created.isNotEmpty) {
        try {
          await Backend.client.storage.from('chat').remove(created);
        } catch (_) {}
      }
    }
    if (pair == null) {
      _summary = 'Проверка файлов доступна только в паре с сервером.';
    } else if (!bigOk && chunksOk) {
      await Transfer.setPreferChunks(true);
      _summary =
          'Сеть обрывает крупные передачи, но частями всё проходит. '
          'Режим «частями» включён — фото, видео и голосовые теперь будут доходить '
          '(немного медленнее). Ещё можно включить VPN «для всех приложений».';
    } else if (bigOk) {
      _summary =
          'Крупные файлы проходят. Если фото всё равно не открываются — '
          'пришлите скриншот этого отчёта.';
    } else {
      _summary =
          'Не проходят ни целые файлы, ни части. Включите VPN '
          '«для всех приложений» (не только для браузера) и проверьте ещё раз.';
    }
    if (mounted) setState(() => _running = false);
  }

  String _report() {
    final b = StringBuffer()
      ..writeln('V&V проверка связи · версия $kBuild')
      ..writeln(kIsWeb ? 'веб' : defaultTargetPlatform.name)
      ..writeln('основной путь: ${_label(Backend.activeUrl)}')
      ..writeln('режим частями: ${Transfer.preferChunks ? 'вкл' : 'выкл'}');
    for (final st in _steps) {
      b.writeln(
        '${st.ok == null ? '…' : (st.ok! ? '✅' : '❌')} ${st.title}: '
        '${st.detail} (${st.ms} мс)',
      );
    }
    if (_summary.isNotEmpty) b.writeln(_summary);
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Проверка связи'),
        actions: [
          if (_steps.isNotEmpty)
            IconButton(
              tooltip: 'Скопировать отчёт',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _report()));
                toast(context, 'Отчёт скопирован');
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Проверим, проходят ли через вашу сеть фото, видео и файлы. '
                  'Займёт до минуты.',
                  style: TextStyle(color: kInkSoft, height: 1.35),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _running ? null : _run,
                    icon: _running
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Icon(Icons.network_check_rounded),
                    label: Text(_running ? 'Проверяю…' : 'Проверить'),
                  ),
                ),
                const SizedBox(height: 6),
                SwitchRow(
                  title: const Text('Передавать файлы частями'),
                  subtitle: const Text(
                    'Медленнее, но проходит там, где сеть рвёт крупные файлы',
                  ),
                  value: Transfer.preferChunks,
                  onChanged: (v) async {
                    await Transfer.setPreferChunks(v);
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
          if (_summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            SoftCard(
              child: Text(
                _summary,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final st in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: st.ok == null
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            )
                          : Text(
                              st.ok! ? '✅' : '❌',
                              style: const TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            st.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (st.detail.isNotEmpty || st.ok != null)
                            Text(
                              '${st.detail}${st.ok == null ? '' : ' · ${st.ms} мс'}',
                              style: TextStyle(color: kInkSoft, fontSize: 13),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
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
}
