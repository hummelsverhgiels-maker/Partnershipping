import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../config.dart';
import '../models.dart';

/// Тонкая обёртка над Supabase. Если ключи не заданы, всё отключено.
class Backend {
  static bool get configured =>
      kSupabaseUrl.isNotEmpty && kSupabaseAnonKey.isNotEmpty;

  static bool _initialized = false;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    if (!configured || _initialized) return;
    await Supabase.initialize(
      url: kSupabaseUrl,
      publishableKey: kSupabaseAnonKey,
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
