/// 'cash' | 'bank' | 'credit_card'. Every type shares the same core
/// fields (balance, transactions, transfers), so adding a new type never
/// needs changes outside where the type itself is shown or filtered on.
/// Credit cards additionally use the credit-card-only fields below —
/// [balance] means "amount currently used" for a credit card (so
/// available = [creditLimit] - [balance]), instead of "amount owned".
class AccountModel {
  final String? id;
  final String userId;
  final String name;
  final String currency;
  final double balance;
  final String type;
  final bool isDefault;
  final bool isIncluded;
  final int createdAt;

  // Credit-card-only fields — null/unset for cash and bank accounts.
  final double? creditLimit;
  final int? billingStartDay; // day of month, 1-31
  final int? dueDay; // day of month, 1-31
  final double? interestRatePercent;
  final double? minimumPaymentPercent;

  const AccountModel({
    this.id,
    required this.userId,
    required this.name,
    this.currency = 'LKR',
    required this.balance,
    this.type = 'cash',
    this.isDefault = false,
    this.isIncluded = true,
    required this.createdAt,
    this.creditLimit,
    this.billingStartDay,
    this.dueDay,
    this.interestRatePercent,
    this.minimumPaymentPercent,
  });

  /// Available credit remaining, for a credit-card account. Null when
  /// there's no credit limit set (or this isn't a credit card).
  double? get availableCredit => creditLimit == null ? null : creditLimit! - balance;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'currency': currency,
      'balance': balance,
      'type': type,
      'isDefault': isDefault,
      'isIncluded': isIncluded,
      'createdAt': createdAt,
      'creditLimit': creditLimit,
      'billingStartDay': billingStartDay,
      'dueDay': dueDay,
      'interestRatePercent': interestRatePercent,
      'minimumPaymentPercent': minimumPaymentPercent,
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  factory AccountModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AccountModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      currency: data['currency']?.toString() ?? 'LKR',
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      type: data['type']?.toString() ?? 'cash',
      isDefault: data['isDefault'] == true,
      isIncluded: data['isIncluded'] != false,
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
      creditLimit: (data['creditLimit'] as num?)?.toDouble(),
      billingStartDay: (data['billingStartDay'] as num?)?.toInt(),
      dueDay: (data['dueDay'] as num?)?.toInt(),
      interestRatePercent: (data['interestRatePercent'] as num?)?.toDouble(),
      minimumPaymentPercent: (data['minimumPaymentPercent'] as num?)?.toDouble(),
    );
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel.fromFirestore(
      map['id']?.toString() ?? '',
      map,
    );
  }

  AccountModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? currency,
    double? balance,
    String? type,
    bool? isDefault,
    bool? isIncluded,
    int? createdAt,
    double? creditLimit,
    int? billingStartDay,
    int? dueDay,
    double? interestRatePercent,
    double? minimumPaymentPercent,
  }) {
    return AccountModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isIncluded: isIncluded ?? this.isIncluded,
      createdAt: createdAt ?? this.createdAt,
      creditLimit: creditLimit ?? this.creditLimit,
      billingStartDay: billingStartDay ?? this.billingStartDay,
      dueDay: dueDay ?? this.dueDay,
      interestRatePercent: interestRatePercent ?? this.interestRatePercent,
      minimumPaymentPercent: minimumPaymentPercent ?? this.minimumPaymentPercent,
    );
  }
}
