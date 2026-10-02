class TransferModel {
  final String? id;
  final String userId;
  final String fromAccountId;
  final String toAccountId;
  final double amount;
  final double fee;
  final String? note;
  final String date;
  final int createdAt;

  const TransferModel({
    this.id,
    required this.userId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    this.fee = 0,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'amount': amount,
      'fee': fee,
      'note': note,
      'date': date,
      'createdAt': createdAt,
    };
  }

  factory TransferModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return TransferModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      fromAccountId: data['fromAccountId']?.toString() ?? '',
      toAccountId: data['toAccountId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      fee: (data['fee'] as num?)?.toDouble() ?? 0,
      note: data['note']?.toString(),
      date: data['date']?.toString() ?? '',
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
