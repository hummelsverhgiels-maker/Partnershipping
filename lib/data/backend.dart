import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../config.dart';
import '../models.dart';
import 'probe_io.dart' if (dart.library.js_interop) 'probe_web.dart';

/// Тонкая обёртка над Supabase. Если ключи не заданы, всё отключено.
class Backend {
  static bool get configured =>
      kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

  static bool _initialized = false;

  static SupabaseClient get client => Supabase.instance.client;

  /// Адрес, который реально используется (прямой или через посредника).
  static String activeUrl = kSupabaseUrl;

  /// Выбор пути к серверу. Запоминаем, что сработало в прошлый раз,
  /// чтобы там, где обычный адрес заблокирован, не ждать каждый запуск.
  static Future<String> _pickUrl() async {
    if (kSupabaseProxyUrl.isEmpty) return kSupabaseUrl;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final lastProxy = prefs?.getString('server_choice') == 'proxy';

    Future<String?> tryProxy() async =>
        await probeServer(kSupabaseProxyUrl) ? kSupabaseProxyUrl : null;
    Future<String?> tryDirect() async =>
        await probeServer(kSupabaseUrl) ? kSupabaseUrl : null;

    String? chosen;
    if (lastProxy) {
      chosen = await tryProxy() ?? await tryDirect();
    } else {
      final proxy = tryProxy(); // параллельно, чтобы не ждать лишнего
      chosen = await tryDirect() ?? await proxy;
    }
    chosen ??= kSupabaseUrl;
    await prefs?.setString(
      'server_choice',
      chosen == kSupabaseProxyUrl ? 'proxy' : 'direct',
    );
    return chosen;
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

  // ---- файлы чата (Supabase Storage, бакет «chat») ----
  static Future<void> uploadFile(
    String path,
    Uint8List bytes,
    String contentType,
  ) async {
    await client.storage
        .from('chat')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
  }

  static Future<String> signedUrl(String path) =>
      client.storage.from('chat').createSignedUrl(path, 3600);

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
