import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'backend.dart';

/// Передача файлов маленькими кусочками.
///
/// Некоторые сети (особенно в России с 2025 года) обрывают или «замораживают»
/// соединение с зарубежными облаками после ~16 КБ данных. Короткие сообщения
/// проходят, а фото и голосовые — нет. Обход: делить файл на куски по 12 КБ и
/// передавать каждый кусок по новому соединению.
class Transfer {
  static const chunkSize = 12 * 1024;
  static const parallel = 6;

  /// Частями отправляем файлы до 25 МБ (дольше, зато доходят).
  static const maxChunkedUpload = 25 * 1024 * 1024;

  static bool _preferChunks = false;
  static bool _loaded = false;

  /// Сеть уже показала, что крупные передачи не проходят: сразу работаем частями.
  static bool get preferChunks => _preferChunks;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      _preferChunks = p.getBool('transfer_chunks') ?? false;
    } catch (_) {}
  }

  static Future<void> setPreferChunks(bool v) async {
    _preferChunks = v;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('transfer_chunks', v);
    } catch (_) {}
  }

  static Map<String, String> _withClose(Map<String, String> h) =>
      kIsWeb ? h : {...h, 'Connection': 'close'};

  /// Один короткий запрос по новому соединению.
  static Future<http.Response> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Uint8List? body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final c = http.Client();
    try {
      final req = http.Request(method, uri)
        ..headers.addAll(_withClose(headers));
      if (body != null) req.bodyBytes = body;
      final streamed = await c.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } finally {
      c.close();
    }
  }

  static String partName(String path, int i) =>
      '$path.p${i.toString().padLeft(4, '0')}';

  /// 'chunks:N:путь' -> (N, путь)
  static (int, String)? parseChunked(String p) {
    if (!p.startsWith('chunks:')) return null;
    final i = p.indexOf(':', 7);
    if (i < 0) return null;
    final n = int.tryParse(p.substring(7, i));
    if (n == null) return null;
    return (n, p.substring(i + 1));
  }

  static List<String> allObjectNames(String path) {
    final c = parseChunked(path);
    if (c == null) return [path];
    return [for (var i = 0; i < c.$1; i++) partName(c.$2, i)];
  }

  // ------------------------------------------------------------ отправка
  static Future<void> uploadPart(
    String objectPath,
    Uint8List bytes, {
    List<String>? bases,
  }) async {
    final token = await Backend.authToken();
    Object? last;
    for (final base in bases ?? Backend.bases) {
      for (var a = 0; a < 3; a++) {
        try {
          final r = await send(
            'POST',
            Uri.parse('$base/storage/v1/object/chat/$objectPath'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/octet-stream',
              'x-upsert': 'true',
            },
            body: bytes,
          );
          if (r.statusCode >= 200 && r.statusCode < 300) return;
          throw StorageRejected(r.statusCode, r.body);
        } catch (e) {
          if (e is StorageRejected) rethrow;
          last = e;
          await Future<void>.delayed(Duration(milliseconds: 300 * (a + 1)));
        }
      }
    }
    throw last ?? 'Кусок файла не отправился';
  }

  /// Отправить файл кусками. Возвращает «путь» вида chunks:N:путь.
  static Future<String> uploadChunked(
    String path,
    Uint8List bytes, {
    void Function(double)? onProgress,
    List<String>? bases,
  }) async {
    final n = max(1, (bytes.length / chunkSize).ceil());
    var next = 0;
    var done = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= n) return;
        final end = min(bytes.length, (i + 1) * chunkSize);
        await uploadPart(
          partName(path, i),
          Uint8List.sublistView(bytes, i * chunkSize, end),
          bases: bases,
        );
        done++;
        onProgress?.call(done / n);
      }
    }

    await Future.wait([for (var k = 0; k < min(parallel, n); k++) worker()]);
    return 'chunks:$n:$path';
  }

  // ----------------------------------------------------------- скачивание
  static Future<http.Response> _getWithFallback(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    final candidates = <String>[url, ?Backend.alternate(url)];
    Object? last;
    for (final u in candidates) {
      for (var a = 0; a < 3; a++) {
        try {
          final r = await send('GET', Uri.parse(u), headers: headers);
          if (r.statusCode == 200 || r.statusCode == 206) return r;
          throw 'Сервер вернул код ${r.statusCode}';
        } catch (e) {
          if (e is String) rethrow;
          last = e;
          await Future<void>.delayed(Duration(milliseconds: 300 * (a + 1)));
        }
      }
    }
    throw last ?? 'Не удалось скачать';
  }

  /// Скачать файл одним запросом, но если данные «застыли» на 10 секунд —
  /// бросаем (сеть их, скорее всего, заморозила).
  static Future<Uint8List> fetchWhole(String url) async {
    final candidates = <String>[url, ?Backend.alternate(url)];
    Object? last;
    for (final u in candidates) {
      final c = http.Client();
      try {
        final r = await c
            .send(http.Request('GET', Uri.parse(u)))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) throw 'Сервер вернул код ${r.statusCode}';
        final b = BytesBuilder(copy: false);
        await for (final part in r.stream.timeout(
          const Duration(seconds: 10),
        )) {
          b.add(part);
        }
        return b.takeBytes();
      } catch (e) {
        if (e is String) rethrow;
        last = e;
      } finally {
        c.close();
      }
    }
    throw last ?? 'Не удалось скачать';
  }

  /// Подписать несколько файлов одним коротким запросом.
  static Future<Map<String, String>> _signBatch(List<String> names) async {
    final token = await Backend.authToken();
    Object? last;
    for (final base in Backend.bases) {
      for (var a = 0; a < 3; a++) {
        try {
          final r = await send(
            'POST',
            Uri.parse('$base/storage/v1/object/sign/chat'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: Uint8List.fromList(
              utf8.encode(jsonEncode({'expiresIn': 3600, 'paths': names})),
            ),
          );
          if (r.statusCode != 200) throw StorageRejected(r.statusCode, r.body);
          final out = <String, String>{};
          for (final e in jsonDecode(utf8.decode(r.bodyBytes)) as List) {
            final m = e as Map<String, dynamic>;
            final rel = (m['signedURL'] ?? m['signedUrl']) as String?;
            final p = m['path'] as String?;
            if (rel == null || p == null) continue;
            out[p] = rel.startsWith('http') ? rel : '$base/storage/v1$rel';
          }
          return out;
        } catch (e) {
          if (e is StorageRejected) rethrow;
          last = e;
          await Future<void>.delayed(Duration(milliseconds: 300 * (a + 1)));
        }
      }
    }
    throw last ?? 'Не удалось получить ссылки на части файла';
  }

  /// Скачать файл, отправленный кусками.
  static Future<Uint8List> downloadChunked(int n, String path) async {
    final names = [for (var i = 0; i < n; i++) partName(path, i)];
    // ссылки подписываем пачками по 10, каждую пачку — новым соединением,
    // чтобы ответы сервера были короткими
    final urls = <String, String>{};
    final batches = [
      for (var i = 0; i < names.length; i += 10)
        names.sublist(i, min(names.length, i + 10)),
    ];
    var nb = 0;
    Future<void> signer() async {
      while (true) {
        final k = nb++;
        if (k >= batches.length) return;
        urls.addAll(await _signBatch(batches[k]));
      }
    }

    await Future.wait([
      for (var k = 0; k < min(3, batches.length); k++) signer(),
    ]);
    final parts = List<Uint8List?>.filled(n, null);
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= n) return;
        final u = urls[names[i]];
        if (u == null) throw 'Нет ссылки на кусок ${i + 1}';
        parts[i] = (await _getWithFallback(u)).bodyBytes;
      }
    }

    await Future.wait([for (var k = 0; k < min(parallel, n); k++) worker()]);
    final b = BytesBuilder(copy: false);
    for (final p in parts) {
      b.add(p!);
    }
    return b.takeBytes();
  }

  /// Скачать обычный файл диапазонами по 12 КБ (каждый — новым соединением).
  static Future<Uint8List> downloadRanged(String url) async {
    final first = await _getWithFallback(
      url,
      headers: {'Range': 'bytes=0-${chunkSize - 1}'},
    );
    if (first.statusCode == 200) {
      return first.bodyBytes; // сервер отдал всё сразу
    }
    final cr = first.headers['content-range'] ?? '';
    final total = int.tryParse(cr.split('/').last);
    if (total == null) return first.bodyBytes;
    if (total <= chunkSize) return first.bodyBytes;
    final n = (total / chunkSize).ceil();
    final parts = List<Uint8List?>.filled(n, null)..[0] = first.bodyBytes;
    var next = 1;
    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= n) return;
        final from = i * chunkSize;
        final to = min(total, from + chunkSize) - 1;
        parts[i] = (await _getWithFallback(
          url,
          headers: {'Range': 'bytes=$from-$to'},
        )).bodyBytes;
      }
    }

    await Future.wait([
      for (var k = 0; k < min(parallel, n - 1); k++) worker(),
    ]);
    final b = BytesBuilder(copy: false);
    for (final p in parts) {
      b.add(p!);
    }
    return b.takeBytes();
  }
}
