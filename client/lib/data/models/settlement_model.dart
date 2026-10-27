class DebtSettlement {
  final String fromUserId;
  final String toUserId;
  final double amount;
  final String currency;

  const DebtSettlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.currency = 'INR',
  });

  factory DebtSettlement.fromJson(Map<String, dynamic> json) {
    return DebtSettlement(
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'INR',
    );
  }

  Map<String, dynamic> toJson() => {
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'amount': amount,
        'currency': currency,
      };

  @override
  String toString() =>
      'DebtSettlement($fromUserId pays $toUserId: $currency $amount)';
}
