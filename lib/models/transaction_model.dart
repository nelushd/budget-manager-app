class TransactionModel {
  final String? id;
  final String title;
  final double amount;
  final String type;
  final String categoryId;
  final String accountId;
  final String? note;
  final String? receiptPath;
  final String date;
  final String time;
  final int createdAt;

  const TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.note,
    this.receiptPath,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'accountId': accountId,
      'note': note,
      'receiptPath': receiptPath,
      'date': date,
      'time': time,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  factory TransactionModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return TransactionModel(
      id: id,
      title: data['title']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: data['type']?.toString() ?? 'expense',
      categoryId: data['categoryId']?.toString() ?? '',
      accountId: data['accountId']?.toString() ?? '',
      note: data['note']?.toString(),
      receiptPath: data['receiptPath']?.toString(),
      date: data['date']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel.fromFirestore(
      map['id']?.toString() ?? '',
      map,
    );
  }

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    String? type,
    String? categoryId,
    String? accountId,
    String? note,
    String? receiptPath,
    String? date,
    String? time,
    int? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      receiptPath: receiptPath ?? this.receiptPath,
      date: date ?? this.date,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}