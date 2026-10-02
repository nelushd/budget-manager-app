class GoalTransactionModel {
  final String? id;
  final String goalId;
  final double amount;
  final String type; // deposit | withdraw
  final String date; // 'YYYY-MM-DD'
  final String? note;
  final int createdAt;

  const GoalTransactionModel({
    this.id,
    required this.goalId,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'amount': amount,
      'type': type,
      'date': date,
      'note': note,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory GoalTransactionModel.fromFirestore(String id, Map<String, dynamic> data) {
    return GoalTransactionModel(
      id: id,
      goalId: data['goalId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      type: data['type']?.toString() ?? 'deposit',
      date: data['date']?.toString() ?? '',
      note: data['note']?.toString(),
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  factory GoalTransactionModel.fromMap(Map<String, dynamic> map) {
    return GoalTransactionModel.fromFirestore(map['id']?.toString() ?? '', map);
  }
}
