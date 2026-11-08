import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/schedule.dart';
import '../models.dart';
import '../util.dart';
import 'backend.dart';

class _Op {
  final bool isDelete;
  final Rec? rec;
  final String id;
  _Op.upsert(Rec r) : isDelete = false, rec = r, id = r.id;
  _Op.delete(this.id) : isDelete = true, rec = null;

  Map<String, dynamic> toJson() =>
      isDelete ? {'t': 'd', 'id': id} : {'t': 'u', 'rec': rec!.toJson()};

  static _Op fromJson(Map<String, dynamic> j) => j['t'] == 'd'
      ? _Op.delete(j['id'] as String)
      : _Op.upsert(Rec.fromJson(Map<String, dynamic>.from(j['rec'] as Map)));
}

/// Всё состояние приложения: пара, участники, записи, синхронизация.
class AppStore extends ChangeNotifier {
  SharedPreferences? _prefs;

  PairSession? session;
  List<Member> members = [];
  Map<String, Rec> _recs = {};
  final List<_Op> _outbox = [];
  final List<(_Op, DateTime)> _grace = [];

  bool loaded = false;
  bool online = false; // удалось ли связаться с сервером
  String? lastError;
  String? lastErrorRaw;
  bool _synced = false;

  StreamSubscription? _recSub;
  StreamSubscription? _memSub;
  Timer? _timer;
  bool _flushing = false;

  /// Вызывается, когда партнёр что-то изменил (категория: schedule, shopping, todo, event).
  void Function(String who, Set<String> categories)? onPartnerChange;

  // ---- производные данные ----
  Schedule schedule = const Schedule();
  List<Rec> events = [];
  List<Rec> shopping = [];
  List<Rec> todos = [];
  List<Rec> templates = [];
  List<Rec> messages = [];
  List<Rec> importantDates = [];
  List<Rec> expenses = [];
  List<Rec> goals = [];
  List<Rec> wishes = [];

  bool get hasSession => session != null;
  bool get isLocal => session?.local ?? true;

  Member? get me {
    for (final m in members) {
      if (m.id == session?.memberId) return m;
    }
    return null;
  }

  Member? get partner {
    for (final m in members) {
      if (m.id != session?.memberId) return m;
    }
    return null;
  }

  Member? memberById(String? id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Я первым, потом партнёр.
  List<Member> get orderedMembers {
    final out = <Member>[];
    if (me != null) out.add(me!);
    if (partner != null) out.add(partner!);
    return out;
  }

  int get pendingCount => _outbox.length;

  // ---------------------------------------------------------------- старт
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final s = _prefs!.getString('session');
      if (s != null) {
        session = PairSession.fromJson(jsonDecode(s) as Map<String, dynamic>);
      }
      final m = _prefs!.getString('members');
      if (m != null) {
        members = (jsonDecode(m) as List)
            .map((e) => Member.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      final r = _prefs!.getString('recs');
      if (r != null) {
        _recs = {
          for (final e in jsonDecode(r) as List)
            (e['id'] as String): Rec.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
        };
      }
      final o = _prefs!.getString('outbox');
      if (o != null) {
        _outbox.addAll(
          (jsonDecode(o) as List).map(
            (e) => _Op.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка чтения локальных данных: $e');
    }
    _rebuild();
    loaded = true;
    notifyListeners();
    if (session != null) _connect();
  }

  bool getFlag(String key, {bool def = true}) => _prefs?.getBool(key) ?? def;

  Future<void> setFlag(String key, bool v) async {
    await _prefs?.setBool(key, v);
    notifyListeners();
  }

  // ------------------------------------------------------- пара и вход
  Future<void> startLocal(String name, int color) async {
    final id = newId();
    session = PairSession(
      pairId: newId(),
      code: 'LOCAL',
      memberId: id,
      local: true,
    );
    members = [Member(id: id, name: name, color: color)];
    _recs = {};
    await _persistAll();
    _rebuild();
    notifyListeners();
  }

  Future<void> createPair(String name, int color) async {
    final s = await Backend.createPair(name, color);
    await _adopt(s, [Member(id: s.memberId, name: name, color: color)]);
  }

  Future<void> joinPair(String code, String name, int color) async {
    final s = await Backend.joinPair(code, name, color);
    await _adopt(s, [Member(id: s.memberId, name: name, color: color)]);
  }

  Future<void> claimMember(String code, Member member) async {
    final s = await Backend.claimMember(code, member.id);
    await _adopt(s, [member]);
  }

  Future<void> _adopt(PairSession s, List<Member> initialMembers) async {
    session = s;
    members = initialMembers;
    _recs = {};
    _outbox.clear();
    _grace.clear();
    _synced = false;
    await _persistAll();
    _rebuild();
    notifyListeners();
    _connect();
  }

  Future<void> leavePair() async {
    _disconnect();
    session = null;
    members = [];
    _recs = {};
    _outbox.clear();
    await _prefs?.remove('session');
    await _prefs?.remove('members');
    await _prefs?.remove('recs');
    await _prefs?.remove('outbox');
    _rebuild();
    notifyListeners();
  }

  // ----------------------------------------------------- синхронизация
  bool _retryScheduled = false;

  void _scheduleRetry() {
    if (online) {
      online = false;
      notifyListeners();
    }
    if (_retryScheduled) return;
    _retryScheduled = true;
    Timer(const Duration(seconds: 15), () {
      _retryScheduled = false;
      _connect();
    });
  }

  Future<void> _connect() async {
    final s = session;
    if (s == null || s.local || !Backend.configured) return;
    try {
      await Backend.ensureSignedIn();
    } catch (e) {
      lastError = Backend.explain(e);
      lastErrorRaw = e.toString();
      _scheduleRetry();
      return;
    }
    await _recSub?.cancel();
    await _memSub?.cancel();
    _recSub = Backend.recordsStream(s.pairId).listen((rows) {
      final was = online;
      online = true;
      _applyRecords(rows);
      if (!was) notifyListeners();
    }, onError: (_) => _scheduleRetry());
    _memSub = Backend.membersStream(
      s.pairId,
    ).listen((rows) => _applyMembers(rows), onError: (_) => _scheduleRetry());
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    await refresh();
  }

  void _disconnect() {
    _recSub?.cancel();
    _memSub?.cancel();
    _timer?.cancel();
    _recSub = null;
    _memSub = null;
    _timer = null;
    online = false;
  }

  int _failStreak = 0;

  /// Принудительно сверить всё с сервером (и отправить накопленное).
  Future<void> refresh() async {
    final s = session;
    if (s == null || s.local || !Backend.configured) return;
    try {
      await Backend.ensureSignedIn();
      await flush();
      final rows = await Backend.fetchRecords(s.pairId);
      final mem = await Backend.fetchMembers(s.pairId);
      final statusChanged = !online || lastError != null;
      online = true;
      lastError = null;
      lastErrorRaw = null;
      _failStreak = 0;
      _applyMembers(mem);
      _applyRecords(rows);
      if (statusChanged) notifyListeners();
    } catch (e) {
      final raw = e.toString();
      final changed = online || lastErrorRaw != raw;
      lastError = Backend.explain(e);
      lastErrorRaw = raw;
      online = false;
      if (changed) notifyListeners();
      // Если путь к серверу стабильно не работает, переключаемся на запасной.
      if (Backend.isNetworkError(e)) {
        _failStreak++;
        if (_failStreak >= 3) {
          _failStreak = 0;
          await Backend.switchPathIfPossible();
        }
      }
    }
  }

  Future<void> flush() async {
    final s = session;
    if (s == null || s.local || !Backend.configured || _flushing) return;
    _flushing = true;
    final beforeCount = _outbox.length;
    final beforeOnline = online;
    try {
      while (_outbox.isNotEmpty) {
        // Берём подряд идущие однотипные операции и отправляем одним запросом.
        final first = _outbox.first;
        var n = 1;
        while (n < _outbox.length &&
            n < 100 &&
            _outbox[n].isDelete == first.isDelete) {
          n++;
        }
        final batch = _outbox.sublist(0, n);
        if (first.isDelete) {
          await Backend.deleteRecords(batch.map((o) => o.id).toList());
        } else {
          await Backend.upsertRecords(
            s.pairId,
            batch.map((o) => o.rec!).toList(),
          );
        }
        _outbox.removeRange(0, n);
        final now = DateTime.now();
        for (final op in batch) {
          _grace.add((op, now));
        }
        await _saveOutbox();
      }
      online = true;
    } catch (e) {
      lastError = Backend.explain(e);
      lastErrorRaw = e.toString();
      online = false;
    } finally {
      _flushing = false;
      if (_outbox.length != beforeCount || online != beforeOnline) {
        notifyListeners();
      }
    }
  }

  void _applyMembers(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return;
    final next = rows.map(Member.fromJson).toList();
    if (_sameMembers(members, next)) return;
    members = next;
    _prefs?.setString(
      'members',
      jsonEncode(next.map((m) => m.toJson()).toList()),
    );
    _rebuild();
    notifyListeners();
  }

  void _applyRecords(List<Map<String, dynamic>> rows) {
    final next = <String, Rec>{};
    for (final r in rows) {
      try {
        final rec = Rec.fromJson(r);
        next[rec.id] = rec;
      } catch (_) {}
    }
    // Свои ещё не отправленные изменения поверх серверных.
    _grace.removeWhere(
      (g) => DateTime.now().difference(g.$2) > const Duration(seconds: 20),
    );
    for (final op in [..._grace.map((g) => g.$1), ..._outbox]) {
      if (op.isDelete) {
        next.remove(op.id);
      } else {
        next[op.id] = op.rec!;
      }
    }

    if (_synced && onPartnerChange != null) {
      final cats = <String>{};
      for (final rec in next.values) {
        if (rec.updatedBy == null || rec.updatedBy == session?.memberId) {
          continue;
        }
        final old = _recs[rec.id];
        if (old != null && !rec.updatedAt.isAfter(old.updatedAt)) continue;
        if (rec.kind == 'message') {
          final edited = rec.i('editedAt');
          final recentEdit =
              edited != null &&
              DateTime.now().millisecondsSinceEpoch - edited < 120000;
          if (recentEdit ||
              (rec.s('from') != null && rec.s('from') != rec.updatedBy)) {
            continue; // правка (важное, реакция), а не новое сообщение
          }
        }
        final c = _category(rec.kind);
        if (c != null) cats.add(c);
      }
      if (cats.isNotEmpty) {
        onPartnerChange!(partner?.name ?? 'Партнёр', cats);
      }
    }
    final same = _sameRecs(_recs, next);
    _synced = true;
    if (same) return; // ничего не изменилось: не перерисовываем экран
    _recs = next;
    _rebuild();
    _saveRecs();
    notifyListeners();
  }

  bool _sameMembers(List<Member> a, List<Member> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].name != b[i].name ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }

  bool _sameRecs(Map<String, Rec> a, Map<String, Rec> b) {
    if (a.length != b.length) return false;
    for (final e in b.entries) {
      final o = a[e.key];
      if (o == null ||
          o.updatedAt != e.value.updatedAt ||
          o.updatedBy != e.value.updatedBy ||
          o.kind != e.value.kind) {
        return false;
      }
    }
    return true;
  }

  String? _category(String kind) {
    switch (kind) {
      case 'shift':
      case 'dayoff':
        return 'schedule';
      case 'shopping':
        return 'shopping';
      case 'todo':
        return 'todo';
      case 'message':
        return 'chat';
      case 'event':
        return 'event';
    }
    return null;
  }

  // ------------------------------------------------------------- чат
  int get chatSeen => _prefs?.getInt('chat_seen') ?? 0;

  /// Автор сообщения (а не тот, кто последним поменял пометку «важное»).
  String? authorOf(Rec m) => m.s('from') ?? m.updatedBy;

  int get unreadChat {
    final meId = session?.memberId;
    final seen = chatSeen;
    return messages
        .where((m) => authorOf(m) != meId && (m.i('ts') ?? 0) > seen)
        .length;
  }

  Future<void> markChatSeen() async {
    final latest = messages.isEmpty ? 0 : (messages.last.i('ts') ?? 0);
    if (latest <= chatSeen) return;
    await _prefs?.setInt('chat_seen', latest);
    notifyListeners();
  }

  Map<String, dynamic> _replyData(Rec? replyTo) {
    if (replyTo == null) return const {};
    final t = replyTo.s('text');
    final type = replyTo.s('type') ?? 'text';
    final snippet = (t != null && t.isNotEmpty)
        ? t
        : switch (type) {
            'image' => '📷 Фото',
            'video' => '🎥 Видео',
            'audio' => '🎤 Голосовое',
            'file' => '📎 ${replyTo.s('name') ?? 'Файл'}',
            _ => 'Сообщение',
          };
    return {
      'replyTo': replyTo.id,
      'replyName': memberById(authorOf(replyTo))?.name ?? '',
      'replyText': snippet.length > 90
          ? '${snippet.substring(0, 90)}…'
          : snippet,
    };
  }

  void sendMessage(String text, {Rec? replyTo}) {
    final t = text.trim();
    if (t.isEmpty) return;
    upsert('message', {
      'type': 'text',
      'text': t,
      'from': session?.memberId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      ..._replyData(replyTo),
    });
  }

  /// Сообщение с файлом (фото, видео, голосовое, документ). Файл уже загружен.
  void sendMedia({
    required String type, // image | video | audio | file
    required String path,
    required String name,
    required int size,
    int? durationMs,
    String? caption,
    Rec? replyTo,
  }) {
    upsert('message', {
      'type': type,
      'path': path,
      'name': name,
      'size': size,
      'dur': ?durationMs,
      if (caption != null && caption.trim().isNotEmpty) 'text': caption.trim(),
      'from': session?.memberId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      ..._replyData(replyTo),
    });
  }

  /// Пометить сообщение «важным» (и обратно).
  /// editedAt нужен, чтобы правка не считалась новым сообщением (уведомления).
  void toggleImportant(Rec m) {
    upsert('message', {
      ...m.data,
      'important': !m.b('important'),
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    }, id: m.id);
  }

  /// Реакция эмодзи: повторное нажатие на ту же реакцию снимает её.
  void toggleReaction(Rec m, String emoji) {
    final meId = session?.memberId;
    if (meId == null) return;
    final cur = <String, dynamic>{
      ...Map<String, dynamic>.from((m.data['reactions'] as Map?) ?? const {}),
    };
    if (cur[meId] == emoji) {
      cur.remove(meId);
    } else {
      cur[meId] = emoji;
    }
    upsert('message', {
      ...m.data,
      'reactions': cur,
      'editedAt': DateTime.now().millisecondsSinceEpoch,
    }, id: m.id);
  }

  /// Удалить сообщение (и файл на сервере, если он есть).
  void deleteMessage(Rec m) {
    final path = m.s('path');
    remove(m.id);
    if (path != null && !isLocal) {
      Backend.deleteFile(path).catchError((Object e) {
        debugPrint('Файл не удалён: $e');
      });
    }
  }

  /// Запомнить токен этого устройства для мгновенных уведомлений.
  Future<void> registerDevice(String token, String platform) async {
    final s = session;
    if (s == null || s.local || !Backend.configured) return;
    try {
      await Backend.ensureSignedIn();
      await Backend.upsertDevice(s.pairId, s.memberId, token, platform);
    } catch (e) {
      debugPrint('Устройство не зарегистрировано: $e');
    }
  }

  // --------------------------------------------------------- записи
  Rec? recById(String id) => _recs[id];

  Rec upsert(String kind, Map<String, dynamic> data, {String? id}) {
    final rec = Rec(
      id: id ?? newId(),
      kind: kind,
      data: data,
      updatedBy: session?.memberId,
      updatedAt: DateTime.now(),
    );
    _recs[rec.id] = rec;
    _outbox.add(_Op.upsert(rec));
    _afterLocalChange();
    return rec;
  }

  void remove(String id) {
    if (_recs.remove(id) == null) return;
    _outbox.add(_Op.delete(id));
    _afterLocalChange();
  }

  void _afterLocalChange() {
    _rebuild();
    _saveRecs();
    _saveOutbox();
    notifyListeners();
    flush();
  }

  // ----------------------------------------------- профиль и шаблоны
  Future<void> setMyProfile(String name, int color) async {
    final id = session?.memberId;
    if (id == null) return;
    members = [
      for (final m in members)
        if (m.id == id) Member(id: id, name: name, color: color) else m,
    ];
    _prefs?.setString(
      'members',
      jsonEncode(members.map((m) => m.toJson()).toList()),
    );
    notifyListeners();
    if (!isLocal) {
      try {
        await Backend.updateMember(id, name, color);
      } catch (e) {
        lastError = Backend.explain(e);
        notifyListeners();
      }
    }
  }

  // ----------------------------------------------- смены и выходные
  void _clearDay(String memberId, String date) {
    final victims = _recs.values.where(
      (r) =>
          (r.kind == 'shift' || r.kind == 'dayoff') &&
          r.s('memberId') == memberId &&
          r.s('date') == date,
    );
    for (final r in victims.toList()) {
      _recs.remove(r.id);
      _outbox.add(_Op.delete(r.id));
    }
  }

  void setShift(
    String memberId,
    Iterable<DateTime> days,
    String start,
    String end,
  ) {
    for (final d in days) {
      final date = ymd(d);
      _clearDay(memberId, date);
      final rec = Rec(
        id: newId(),
        kind: 'shift',
        data: {'memberId': memberId, 'date': date, 'start': start, 'end': end},
        updatedBy: session?.memberId,
        updatedAt: DateTime.now(),
      );
      _recs[rec.id] = rec;
      _outbox.add(_Op.upsert(rec));
    }
    _afterLocalChange();
  }

  void setDayOff(String memberId, Iterable<DateTime> days) {
    for (final d in days) {
      final date = ymd(d);
      _clearDay(memberId, date);
      final rec = Rec(
        id: newId(),
        kind: 'dayoff',
        data: {'memberId': memberId, 'date': date},
        updatedBy: session?.memberId,
        updatedAt: DateTime.now(),
      );
      _recs[rec.id] = rec;
      _outbox.add(_Op.upsert(rec));
    }
    _afterLocalChange();
  }

  void clearDays(String memberId, Iterable<DateTime> days) {
    for (final d in days) {
      _clearDay(memberId, ymd(d));
    }
    _afterLocalChange();
  }

  // ------------------------------------------------------ выплаты
  bool shiftPayFor(String memberId) => schedule.shiftPay[memberId] ?? false;

  Rec? _prefsRec(String memberId) {
    for (final r in _recs.values) {
      if (r.kind == 'prefs' && r.s('memberId') == memberId) return r;
    }
    return null;
  }

  void setShiftPay(String memberId, bool value) {
    final existing = _prefsRec(memberId);
    upsert('prefs', {
      ...?existing?.data,
      'memberId': memberId,
      'shiftPay': value,
    }, id: existing?.id);
  }

  /// Ставка за час (₽). 0 — не задана.
  double hourRateFor(String memberId) =>
      (_prefsRec(memberId)?.data['hourRate'] as num?)?.toDouble() ?? 0;

  void setHourRate(String memberId, double rate) {
    final existing = _prefsRec(memberId);
    upsert('prefs', {
      ...?existing?.data,
      'memberId': memberId,
      'hourRate': rate,
    }, id: existing?.id);
  }

  /// График по шаблону: смены на рабочие дни (и, если нужно, явные «выходные»).
  void applyPattern({
    required String memberId,
    required List<DateTime> workDays,
    required List<DateTime> offDays,
    required String start,
    required String end,
    required bool markOff,
    required bool clearOff,
  }) {
    for (final d in workDays) {
      _clearDay(memberId, ymd(d));
    }
    if (markOff) {
      for (final d in offDays) {
        _clearDay(memberId, ymd(d));
      }
    } else if (clearOff) {
      for (final d in offDays) {
        _clearDay(memberId, ymd(d));
      }
    }
    for (final d in workDays) {
      final rec = Rec(
        id: newId(),
        kind: 'shift',
        data: {
          'memberId': memberId,
          'date': ymd(d),
          'start': start,
          'end': end,
        },
        updatedBy: session?.memberId,
        updatedAt: DateTime.now(),
      );
      _recs[rec.id] = rec;
      _outbox.add(_Op.upsert(rec));
    }
    if (markOff) {
      for (final d in offDays) {
        final rec = Rec(
          id: newId(),
          kind: 'dayoff',
          data: {'memberId': memberId, 'date': ymd(d)},
          updatedBy: session?.memberId,
          updatedAt: DateTime.now(),
        );
        _recs[rec.id] = rec;
        _outbox.add(_Op.upsert(rec));
      }
    }
    _afterLocalChange();
  }

  /// Важные даты, приходящиеся на этот день (ежегодные учитываются по числу и месяцу).
  List<Rec> importantOn(DateTime d) {
    final out = <Rec>[];
    for (final r in importantDates) {
      final ds = r.s('date');
      if (ds == null) continue;
      final o = parseYmd(ds);
      if (r.b('yearly')) {
        final dim = daysInMonth(d.year, o.month);
        final day = o.day > dim ? dim : o.day;
        if (d.month == o.month && d.day == day) out.add(r);
      } else if (o.year == d.year && o.month == d.month && o.day == d.day) {
        out.add(r);
      }
    }
    return out;
  }

  // -------------------------------------------------- производные
  void _rebuild() {
    final shifts = <String, Map<String, ShiftInfo>>{};
    final offs = <String>{};
    final rules = <PayRule>[];
    final pdates = <PayDate>[];
    final shiftPay = <String, bool>{};
    final ev = <Rec>[];
    final sh = <Rec>[];
    final td = <Rec>[];
    final tp = <Rec>[];
    final msgs = <Rec>[];
    final imp = <Rec>[];
    final exp = <Rec>[];
    final gl = <Rec>[];
    final wi = <Rec>[];
    final dm = <String>{};
    for (final r in _recs.values) {
      switch (r.kind) {
        case 'shift':
          final m = r.s('memberId');
          final d = r.s('date');
          final s = r.s('start');
          final e = r.s('end');
          if (m != null && d != null && s != null && e != null) {
            (shifts[d] ??= {})[m] = ShiftInfo(r.id, s, e);
            dm.add('$m|${d.substring(0, 7)}');
          }
        case 'dayoff':
          final m = r.s('memberId');
          final d = r.s('date');
          if (m != null && d != null) {
            offs.add('$m|$d');
            dm.add('$m|${d.substring(0, 7)}');
          }
        case 'payrule':
          final m = r.s('memberId');
          final day = r.i('day');
          if (m != null && day != null) {
            rules.add(PayRule(r.id, m, day, r.s('label') ?? 'Выплата'));
          }
        case 'paydate':
          final m = r.s('memberId');
          final d = r.s('date');
          if (m != null && d != null) {
            pdates.add(PayDate(r.id, m, d, r.s('label') ?? 'Выплата'));
          }
        case 'prefs':
          final m = r.s('memberId');
          if (m != null) shiftPay[m] = r.b('shiftPay');
        case 'event':
          ev.add(r);
        case 'shopping':
          sh.add(r);
        case 'todo':
          td.add(r);
        case 'template':
          tp.add(r);
        case 'message':
          msgs.add(r);
        case 'important':
          imp.add(r);
        case 'expense':
          exp.add(r);
        case 'goal':
          gl.add(r);
        case 'wish':
          wi.add(r);
      }
    }
    // Если смена и «выходной» вдруг оба есть (две правки одновременно) — побеждает смена.
    schedule = Schedule(
      shifts: shifts,
      offMarks: offs,
      rules: rules,
      payDates: pdates,
      shiftPay: shiftPay,
      dataMonths: dm,
    );
    ev.sort((a, b) {
      final c = (a.s('date') ?? '').compareTo(b.s('date') ?? '');
      return c != 0 ? c : (a.s('time') ?? '').compareTo(b.s('time') ?? '');
    });
    sh.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    td.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    tp.sort((a, b) => (a.s('start') ?? '').compareTo(b.s('start') ?? ''));
    msgs.sort((a, b) => (a.i('ts') ?? 0).compareTo(b.i('ts') ?? 0));
    messages = msgs;
    imp.sort((a, b) => (a.s('date') ?? '').compareTo(b.s('date') ?? ''));
    exp.sort((a, b) {
      final c = (b.s('date') ?? '').compareTo(a.s('date') ?? '');
      return c != 0 ? c : b.updatedAt.compareTo(a.updatedAt);
    });
    gl.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    wi.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    importantDates = imp;
    expenses = exp;
    goals = gl;
    wishes = wi;
    events = ev;
    shopping = sh;
    todos = td;
    templates = tp;
  }

  // -------------------------------------------------- сохранение
  Future<void> _persistAll() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString('session', jsonEncode(session!.toJson()));
    await p.setString(
      'members',
      jsonEncode(members.map((m) => m.toJson()).toList()),
    );
    await _saveRecs();
    await _saveOutbox();
  }

  Future<void> _saveRecs() async => _prefs?.setString(
    'recs',
    jsonEncode(_recs.values.map((r) => r.toJson()).toList()),
  );

  Future<void> _saveOutbox() async => _prefs?.setString(
    'outbox',
    jsonEncode(_outbox.map((o) => o.toJson()).toList()),
  );

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }
}
