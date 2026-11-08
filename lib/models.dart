class Member {
  final String id;
  final String name;
  final int color; // ARGB

  const Member({required this.id, required this.name, required this.color});

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    id: j['id'] as String,
    name: (j['name'] as String?) ?? '',
    color: (j['color'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
}

/// Универсальная запись, которая синхронизируется между телефонами.
/// kind: shift, dayoff, template, payrule, paydate, prefs, event, shopping, todo
class Rec {
  final String id;
  final String kind;
  final Map<String, dynamic> data;
  final String? updatedBy;
  final DateTime updatedAt;

  const Rec({
    required this.id,
    required this.kind,
    required this.data,
    required this.updatedAt,
    this.updatedBy,
  });

  String? s(String k) => data[k] as String?;
  bool b(String k) => data[k] == true;
  int? i(String k) => (data[k] as num?)?.toInt();

  factory Rec.fromJson(Map<String, dynamic> j) => Rec(
    id: j['id'] as String,
    kind: j['kind'] as String,
    data: Map<String, dynamic>.from((j['data'] as Map?) ?? const {}),
    updatedBy: j['updated_by'] as String?,
    updatedAt:
        DateTime.tryParse((j['updated_at'] as String?) ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'data': data,
    'updated_by': updatedBy,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class PairSession {
  final String pairId;
  final String code;
  final String memberId;
  final bool local; // true = без сервера, только этот телефон

  const PairSession({
    required this.pairId,
    required this.code,
    required this.memberId,
    required this.local,
  });

  factory PairSession.fromJson(Map<String, dynamic> j) => PairSession(
    pairId: j['pairId'] as String,
    code: j['code'] as String,
    memberId: j['memberId'] as String,
    local: j['local'] == true,
  );

  Map<String, dynamic> toJson() => {
    'pairId': pairId,
    'code': code,
    'memberId': memberId,
    'local': local,
  };
}
