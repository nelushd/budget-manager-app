class AccountModel {
  final int? id;
  final String name;
  final String currency;
  final double balance;
  final bool isDefault;
  final bool isIncluded;
  final int createdAt;

  AccountModel({
    this.id,
    required this.name,
    this.currency = 'LKR',
    required this.balance,
    this.isDefault = false,
    this.isIncluded = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'balance': balance,
      'isDefault': isDefault ? 1 : 0,
      'isIncluded': isIncluded ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'],
      name: map['name'],
      currency: map['currency'],
      balance: map['balance'],
      isDefault: map['isDefault'] == 1,
      isIncluded: map['isIncluded'] == 1,
      createdAt: map['createdAt'],
    );
  }

  AccountModel copyWith({
    int? id,
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