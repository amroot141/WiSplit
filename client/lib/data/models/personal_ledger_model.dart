enum LedgerStatus {
  UNSETTLED,
  SETTLED,
  CANCELLED;

  String toJson() => name;
  static LedgerStatus fromJson(String value) =>
      LedgerStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == value.toUpperCase(),
        orElse: () => LedgerStatus.UNSETTLED,
      );
}

class PersonalLedgerEntry {
  final String id;
  final String creditorId;
  final String debtorId;
  final double amount;
  final String currency;
  final String description;
  final LedgerStatus status;
  final DateTime? settledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;

  const PersonalLedgerEntry({
    required this.id,
    required this.creditorId,
    required this.debtorId,
    required this.amount,
    this.currency = 'USD',
    required this.description,
    this.status = LedgerStatus.UNSETTLED,
    this.settledAt,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = true,
  });

  PersonalLedgerEntry copyWith({
    String? id,
    String? creditorId,
    String? debtorId,
    double? amount,
    String? currency,
    String? description,
    LedgerStatus? status,
    DateTime? settledAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return PersonalLedgerEntry(
      id: id ?? this.id,
      creditorId: creditorId ?? this.creditorId,
      debtorId: debtorId ?? this.debtorId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      status: status ?? this.status,
      settledAt: settledAt ?? this.settledAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  factory PersonalLedgerEntry.fromJson(Map<String, dynamic> json, {bool isSynced = true}) {
    return PersonalLedgerEntry(
      id: json['id'] as String,
      creditorId: json['creditor_id'] as String,
      debtorId: json['debtor_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      description: json['description'] as String,
      status: LedgerStatus.fromJson(json['status'] as String),
      settledAt: json['settled_at'] != null ? DateTime.parse(json['settled_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isSynced: isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creditor_id': creditorId,
        'debtor_id': debtorId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'status': status.toJson(),
        'settled_at': settledAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'creditor_id': creditorId,
        'debtor_id': debtorId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'status': status.toJson(),
        'settled_at': settledAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
      };

  factory PersonalLedgerEntry.fromSqliteMap(Map<String, dynamic> map) {
    return PersonalLedgerEntry(
      id: map['id'] as String,
      creditorId: map['creditor_id'] as String,
      debtorId: map['debtor_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'USD',
      description: map['description'] as String,
      status: LedgerStatus.fromJson(map['status'] as String),
      settledAt: map['settled_at'] != null ? DateTime.parse(map['settled_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }
}
