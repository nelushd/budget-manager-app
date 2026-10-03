class LendingRepaymentModel {
  final String? id;
  final String lendingId;
  final String accountId;
  final double amount;
  final String date; // 'YYYY-MM-DD'
  final String? note;
  final int createdAt;

  const LendingRepaymentModel({
    this.id,
    required this.lendingId,
    required this.accountId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'lendingId': lendingId,
      'accountId': accountId,
      'amount': amount,
      'date': date,
      'note': note,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory LendingRepaymentModel.fromFirestore(String id, Map<String, dynamic> data) {
    return LendingRepaymentModel(
      id: id,
      lendingId: data['lendingId']?.toString() ?? '',
      accountId: data['accountId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: data['date']?.toString() ?? '',
      note: data['note']?.toString(),
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  factory LendingRepaymentModel.fromMap(Map<String, dynamic> map) {
    return LendingRepaymentModel.fromFirestore(map['id']?.toString() ?? '', map);
  }
}
