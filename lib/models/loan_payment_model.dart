class LoanPaymentModel {
  final String? id;
  final String loanId;
  final String accountId;
  final double amount;
  final String date; // 'YYYY-MM-DD'
  final int createdAt;

  const LoanPaymentModel({
    this.id,
    required this.loanId,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'loanId': loanId,
      'accountId': accountId,
      'amount': amount,
      'date': date,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory LoanPaymentModel.fromFirestore(String id, Map<String, dynamic> data) {
    return LoanPaymentModel(
      id: id,
      loanId: data['loanId']?.toString() ?? '',
      accountId: data['accountId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: data['date']?.toString() ?? '',
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  factory LoanPaymentModel.fromMap(Map<String, dynamic> map) {
    return LoanPaymentModel.fromFirestore(map['id']?.toString() ?? '', map);
  }
}
