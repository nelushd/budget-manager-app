class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String type; // income or expense
  final int categoryId;
  final int accountId;
  final String? note;
  final String? receiptPath;
  final String date;
  final String time;
  final int createdAt;

  TransactionModel({
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      type: map['type'],
      categoryId: map['categoryId'],
      accountId: map['accountId'],
      note: map['note'],
      receiptPath: map['receiptPath'],
      date: map['date'],
      time: map['time'],
      createdAt: map['createdAt'],
    );
  }

  TransactionModel copyWith({
    int? id,
    String? title,
    double? amount,
    String? type,
    int? categoryId,
    int? accountId,
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