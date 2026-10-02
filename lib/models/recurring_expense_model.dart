class RecurringExpenseModel {
  final String? id;
  final String userId;
  final String name;
  final double amount;
  final String categoryId;
  final String frequency; // daily | weekly | biweekly | monthly | quarterly | yearly
  final String startDate; // 'YYYY-MM-DD'
  final String nextDueDate; // 'YYYY-MM-DD'
  final int reminderDays;
  final String accountId;
  final String status; // active | inactive
  final int createdDate;

  const RecurringExpenseModel({
    this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.reminderDays = 3,
    required this.accountId,
    this.status = 'active',
    required this.createdDate,
  });

  bool get isActive => status == 'active';

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'amount': amount,
      'categoryId': categoryId,
      'frequency': frequency,
      'startDate': startDate,
      'nextDueDate': nextDueDate,
      'reminderDays': reminderDays,
      'accountId': accountId,
      'status': status,
      'createdDate': createdDate,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory RecurringExpenseModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RecurringExpenseModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      categoryId: data['categoryId']?.toString() ?? '',
      frequency: data['frequency']?.toString() ?? 'monthly',
      startDate: data['startDate']?.toString() ?? '',
      nextDueDate: data['nextDueDate']?.toString() ?? '',
      reminderDays: (data['reminderDays'] as num?)?.toInt() ?? 0,
      accountId: data['accountId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      createdDate: (data['createdDate'] as num?)?.toInt() ?? 0,
    );
  }

  factory RecurringExpenseModel.fromMap(Map<String, dynamic> map) {
    return RecurringExpenseModel.fromFirestore(map['id']?.toString() ?? '', map);
  }

  RecurringExpenseModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? amount,
    String? categoryId,
    String? frequency,
    String? startDate,
    String? nextDueDate,
    int? reminderDays,
    String? accountId,
    String? status,
    int? createdDate,
  }) {
    return RecurringExpenseModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      reminderDays: reminderDays ?? this.reminderDays,
      accountId: accountId ?? this.accountId,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
