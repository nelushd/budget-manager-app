class AccountModel {
  final String? id;
  final String name;
  final String currency;
  final double balance;
  final bool isDefault;
  final bool isIncluded;
  final int createdAt;

  const AccountModel({
    this.id,
    required this.name,
    this.currency = 'LKR',
    required this.balance,
    this.isDefault = false,
    this.isIncluded = true,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'currency': currency,
      'balance': balance,
      'isDefault': isDefault,
      'isIncluded': isIncluded,
      'createdAt': createdAt,
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
      name: data['name']?.toString() ?? '',
      currency: data['currency']?.toString() ?? 'LKR',
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      isDefault: data['isDefault'] == true,
      isIncluded: data['isIncluded'] != false,
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
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
    String? name,
    String? currency,
    double? balance,
    bool? isDefault,
    bool? isIncluded,
    int? createdAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      balance: balance ?? this.balance,
      isDefault: isDefault ?? this.isDefault,
      isIncluded: isIncluded ?? this.isIncluded,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}