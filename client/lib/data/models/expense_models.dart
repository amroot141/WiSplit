enum SplitType {
  EQUAL,
  EXACT,
  PERCENTAGE,
  SHARES;

  String toJson() => name;
  static SplitType fromJson(String value) =>
      SplitType.values.firstWhere((e) => e.name == value, orElse: () => SplitType.EQUAL);
}

class SplitItemInput {
  final String userId;
  final double? amount;
  final double? percentage;
  final double? shares;

  const SplitItemInput({
    required this.userId,
    this.amount,
    this.percentage,
    this.shares,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'user_id': userId};
    if (amount != null) map['amount'] = amount;
    if (percentage != null) map['percentage'] = percentage;
    if (shares != null) map['shares'] = shares;
    return map;
  }

  factory SplitItemInput.fromJson(Map<String, dynamic> json) {
    return SplitItemInput(
      userId: json['user_id'] as String,
      amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
      shares: json['shares'] != null ? (json['shares'] as num).toDouble() : null,
    );
  }
}

class CreateExpenseRequest {
  final String paidBy;
  final double amount;
  final String currency;
  final String description;
  final SplitType splitType;
  final List<SplitItemInput> splits;
  final DateTime? createdAt;

  const CreateExpenseRequest({
    required this.paidBy,
    required this.amount,
    this.currency = 'INR',
    required this.description,
    this.splitType = SplitType.EQUAL,
    required this.splits,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'paid_by': paidBy,
      'amount': amount,
      'currency': currency,
      'description': description,
      'split_type': splitType.toJson(),
      'splits': splits.map((s) => s.toJson()).toList(),
    };
    if (createdAt != null) {
      map['created_at'] = createdAt!.toIso8601String();
    }
    return map;
  }

  factory CreateExpenseRequest.fromJson(Map<String, dynamic> json) {
    return CreateExpenseRequest(
      paidBy: json['paid_by'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      description: json['description'] as String,
      splitType: SplitType.fromJson(json['split_type'] as String),
      splits: (json['splits'] as List)
          .map((s) => SplitItemInput.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }
}

class ExpenseSplit {
  final String id;
  final String expenseId;
  final String userId;
  final double amount;
  final double? percentage;
  final double? shares;
  final DateTime createdAt;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.amount,
    this.percentage,
    this.shares,
    required this.createdAt,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
      shares: json['shares'] != null ? (json['shares'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'expense_id': expenseId,
        'user_id': userId,
        'amount': amount,
        'percentage': percentage,
        'shares': shares,
        'created_at': createdAt.toIso8601String(),
      };
}

class Expense {
  final String id;
  final String groupId;
  final String paidBy;
  final double amount;
  final String currency;
  final String description;
  final SplitType splitType;
  final DateTime createdAt;
  final List<ExpenseSplit> splits;
  final bool isSynced;

  const Expense({
    required this.id,
    required this.groupId,
    required this.paidBy,
    required this.amount,
    required this.currency,
    required this.description,
    required this.splitType,
    required this.createdAt,
    required this.splits,
    this.isSynced = true,
  });

  factory Expense.fromJson(Map<String, dynamic> json, {bool isSynced = true}) {
    return Expense(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      paidBy: json['paid_by'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
      description: json['description'] as String,
      splitType: SplitType.fromJson(json['split_type'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      splits: (json['splits'] as List? ?? [])
          .map((s) => ExpenseSplit.fromJson(s as Map<String, dynamic>))
          .toList(),
      isSynced: isSynced,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'paid_by': paidBy,
        'amount': amount,
        'currency': currency,
        'description': description,
        'split_type': splitType.toJson(),
        'created_at': createdAt.toIso8601String(),
        'splits': splits.map((s) => s.toJson()).toList(),
      };
}
