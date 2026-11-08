import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../config.dart';
import '../models.dart';
import 'probe_io.dart' if (dart.library.js_interop) 'probe_web.dart';

/// Тонкая обёртка над Supabase. Если ключи не заданы, всё отключено.
class StorageRejected implements Exception {
  final int status;
  final String body;
  StorageRejected(this.status, this.body);

  @override
  String toString() {
    if (status == 413) return 'Файл слишком большой для хранилища (код 413).';
    if (status == 400 || status == 403 || status == 404) {
      return 'Хранилище не приняло файл (код $status). Проверьте, что в Supabase выполнен schema.sql. $body';
    }
    return 'Хранилище ответило кодом $status. $body';
  }
}

class Backend {
  static bool get configured =>
      kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

  static bool _initialized = false;

  static SupabaseClient get client => Supabase.instance.client;

  /// Адрес, который реально используется (прямой или через посредника).
  static String activeUrl = kSupabaseUrl;

  /// Выбор пути к серверу. В браузере (iPhone) всегда сначала пробуем посредника:
  /// он стабильнее у провайдеров, которые режут прямой адрес. На Android сначала
  /// прямой адрес. Ручное или автоматическое переключение действует 30 минут.
  static Future<String> _pickUrl() async {
    if (kSupabaseProxyUrl.isEmpty) return kSupabaseUrl;
    String? override;
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt('server_switch_at') ?? 0;
      final fresh = DateTime.now().millisecondsSinceEpoch - at < 30 * 60 * 1000;
      if (fresh) override = prefs.getString('server_choice');
    } catch (_) {}
    final proxyFirst = kIsWeb ? override != 'direct' : override == 'proxy';

    final first = proxyFirst ? kSupabaseProxyUrl : kSupabaseUrl;
    final second = proxyFirst ? kSupabaseUrl : kSupabaseProxyUrl;
    final probeFirst = probeServer(first);
    final probeSecond = probeServer(
      second,
    ); // параллельно, чтобы не ждать лишнего
    return await probeFirst ? first : (await probeSecond ? second : first);
  }

  static bool isNetworkError(Object e) {
    final t = e.toString();
    return t.contains('ClientException') ||
        t.contains('SocketException') ||
        t.contains('Failed host lookup') ||
        t.contains('Load failed') ||
        t.contains('Failed to fetch') ||
        t.contains('TimeoutException');
  }

  /// Если выбранный путь стабильно не работает, запоминаем другой и
  /// перезапускаем сайт (в приложении на телефоне сработает при следующем запуске).
  static Future<void> switchPathIfPossible({bool force = false}) async {
    if (kSupabaseProxyUrl.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('server_switch_at') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - last < 10 * 60 * 1000) {
        return; // не чаще раза в 10 минут
      }
      final usingProxy = activeUrl == kSupabaseProxyUrl;
      await prefs.setString('server_choice', usingProxy ? 'direct' : 'proxy');
      await prefs.setInt('server_switch_at', now);
      reloadApp();
    } catch (_) {}
  }

  static Future<void> init() async {
    if (!configured || _initialized) return;
    activeUrl = await _pickUrl();
    await Supabase.initialize(
      url: activeUrl,
      publishableKey: kSupabaseAnonKey,
      authOptions: FlutterAuthClientOptions(
        // Ключ хранения входа не зависит от адреса: вход не теряется при смене пути.
        localStorage: SharedPreferencesLocalStorage(
          persistSessionKey:
              'sb-${Uri.parse(kSupabaseUrl).host.split('.').first}-auth-token',
        ),
      ),
    );
    _initialized = true;
  }

  /// Анонимный вход: без логина и пароля.
  static Future<void> ensureSignedIn() async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      Map<String, dynamic>.from(v as Map);

  static Future<PairSession> createPair(String name, int color) async {
    await ensureSignedIn();
    final r = _asMap(
      await client.rpc(
        'create_pair',
        params: {'p_name': name, 'p_color': color},
      ),
    );
    return PairSession(
      pairId: r['pair_id'] as String,
      code: r['code'] as String,
      memberId: r['member_id'] as String,
      local: false,
    );
  }

  /// null — пара с таким кодом не найдена.
  static Future<({String pairId, List<Member> members})?> findPair(
    String code,
  ) async {
    await ensureSignedIn();
    final r = await client.rpc('find_pair', params: {'p_code': code});
    if (r == null) return null;
    final m = _asMap(r);
    return (
      pairId: m['pair_id'] as String,
      members: (m['members'] as List)
          .map((e) => Member.fromJson(_asMap(e)))
          .toList(),
    );
  }

  static Future<PairSession> joinPair(
    String code,
    String name,
    int color,
  ) async {
    await ensureSignedIn();
    final r = _asMap(
      await client.rpc(
        'join_pair',
        params: {'p_code': code, 'p_name': name, 'p_color': color},
      ),
    );
    return PairSession(
      pairId: r['pair_id'] as String,
      code: r['code'] as String,
      memberId: r['member_id'] as String,
      local: false,
    );
  }

  static Future<PairSession> claimMember(String code, String memberId) async {
    await ensureSignedIn();
    final r = _asMap(
      await client.rpc(
        'claim_member',
        params: {'p_code': code, 'p_member_id': memberId},
      ),
    );
    return PairSession(
      pairId: r['pair_id'] as String,
      code: r['code'] as String,
      memberId: r['member_id'] as String,
      local: false,
    );
  }

  static Stream<List<Map<String, dynamic>>> recordsStream(String pairId) =>
      client.from('records').stream(primaryKey: ['id']).eq('pair_id', pairId);

  static Stream<List<Map<String, dynamic>>> membersStream(String pairId) =>
      client.from('members').stream(primaryKey: ['id']).eq('pair_id', pairId);

  static Future<List<Map<String, dynamic>>> fetchRecords(String pairId) async {
    final r = await client.from('records').select().eq('pair_id', pairId);
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<List<Map<String, dynamic>>> fetchMembers(String pairId) async {
    final r = await client.from('members').select().eq('pair_id', pairId);
    return List<Map<String, dynamic>>.from(r);
  }

  static Future<void> upsertRecord(String pairId, Rec r) async {
    await client.from('records').upsert({
      'id': r.id,
      'pair_id': pairId,
      'kind': r.kind,
      'data': r.data,
      'updated_by': r.updatedBy,
    });
  }

  static Future<void> upsertRecords(String pairId, List<Rec> recs) async {
    if (recs.isEmpty) return;
    await client.from('records').upsert([
      for (final r in recs)
        {
          'id': r.id,
          'pair_id': pairId,
          'kind': r.kind,
          'data': r.data,
          'updated_by': r.updatedBy,
        },
    ]);
  }

  static Future<void> deleteRecords(List<String> ids) async {
    if (ids.isEmpty) return;
    await client.from('records').delete().inFilter('id', ids);
  }

  static Future<void> deleteRecord(String id) async {
    await client.from('records').delete().eq('id', id);
  }

  /// Готовые тексты для виджета (читаются из Scriptable по коду пары).
  static Future<void> upsertWidget(
    String pairId,
    String memberId,
    Map<String, dynamic> data,
  ) async {
    await client.from('widget_cache').upsert({
      'member_id': memberId,
      'pair_id': pairId,
      'data': data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> upsertDevice(
    String pairId,
    String memberId,
    String token,
    String platform,
  ) async {
    await client.from('devices').upsert({
      'token': token,
      'member_id': memberId,
      'pair_id': pairId,
      'platform': platform,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ---- файлы (Supabase Storage, бакет «chat») ----

  /// Запасной адрес сервера (если основной не отвечает).
  static String get altUrl {
    if (kSupabaseProxyUrl.isEmpty) return '';
    return activeUrl == kSupabaseProxyUrl ? kSupabaseUrl : kSupabaseProxyUrl;
  }

  static bool _isNetworkIssue(Object e) =>
      e is TimeoutException || e is http.ClientException || isNetworkError(e);

  /// Загрузка файла. Тяжёлые запросы провайдеры иногда обрывают («Connection reset»),
  /// поэтому пробуем несколько раз и, если нужно, через запасной адрес.
  static Future<void> uploadFile(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    var session = client.auth.currentSession;
    if (session == null || session.isExpired) {
      try {
        await ensureSignedIn();
        await client.auth.refreshSession();
      } catch (_) {}
      session = client.auth.currentSession;
    }
    final token = session?.accessToken ?? kSupabaseAnonKey;
    final bases = <String>[activeUrl, if (altUrl.isNotEmpty) altUrl];
    Object? lastError;
    for (final base in bases) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final r = await http
              .post(
                Uri.parse('$base/storage/v1/object/chat/$path'),
                headers: {
                  'apikey': kSupabaseAnonKey,
                  'Authorization': 'Bearer $token',
                  'Content-Type': contentType,
                  'x-upsert': 'true',
                  'cache-control': 'max-age=3600',
                },
                body: bytes,
              )
              .timeout(const Duration(minutes: 4));
          if (r.statusCode >= 200 && r.statusCode < 300) return;
          // Сервер ответил отказом: это не сетевой сбой, повторять нет смысла.
          throw StorageRejected(r.statusCode, r.body);
        } catch (e) {
          if (e is StorageRejected) rethrow;
          if (!_isNetworkIssue(e)) rethrow;
          lastError = e;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    throw lastError ?? 'Не удалось отправить файл';
  }

  static Future<String> signedUrl(String path) =>
      client.storage.from('chat').createSignedUrl(path, 3600);

  /// Тот же адрес, но через запасной путь.
  static String? alternate(String url) {
    if (altUrl.isEmpty || !url.startsWith(activeUrl)) return null;
    return altUrl + url.substring(activeUrl.length);
  }

  static Future<void> deleteFile(String path) async {
    await client.storage.from('chat').remove([path]);
  }

  static Future<void> updateMember(String id, String name, int color) async {
    await client
        .from('members')
        .update({'name': name, 'color': color})
        .eq('id', id);
  }

  /// Человекочитаемая ошибка.
  static String explain(Object e) {
    final s = e.toString();
    if (s.contains('pair_full')) {
      return 'В этой паре уже двое. Выберите, кто из них вы.';
    }
    if (s.contains('pair_not_found')) return 'Пара с таким кодом не найдена.';
    if (s.contains('Anonymous sign-ins are disabled') ||
        s.contains('anonymous_provider_disabled')) {
      return 'На сервере не включён анонимный вход (Supabase → Authentication → Sign In / Providers → Anonymous).';
    }
    if (s.contains('Failed host lookup') ||
        s.contains('SocketException') ||
        s.contains('ClientException')) {
      return 'Нет связи с интернетом.';
    }
    if (s.contains('Could not find the function') ||
        s.contains('PGRST202') ||
        s.contains('relation') && s.contains('does not exist')) {
      return 'На сервере не выполнен SQL-скрипт (supabase/schema.sql).';
    }
    return 'Ошибка: $s';
  }
}
