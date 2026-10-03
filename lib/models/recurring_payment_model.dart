class RecurringPaymentModel {
  final String? id;
  final String expenseId;
  final String accountId;
  final String? transactionId;
  final String paymentDate; // 'YYYY-MM-DD'
  final double amount;
  final String status; // paid | missed

  const RecurringPaymentModel({
    this.id,
    required this.expenseId,
    required this.accountId,
    this.transactionId,
    required this.paymentDate,
    required this.amount,
    this.status = 'paid',
  });

  Map<String, dynamic> toFirestore() {
    return {
      'expenseId': expenseId,
      'accountId': accountId,
      'transactionId': transactionId,
      'paymentDate': paymentDate,
      'amount': amount,
      'status': status,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory RecurringPaymentModel.fromFirestore(String id, Map<String, dynamic> data) {
    return RecurringPaymentModel(
      id: id,
      expenseId: data['expenseId']?.toString() ?? '',
      accountId: data['accountId']?.toString() ?? '',
      transactionId: data['transactionId']?.toString(),
      paymentDate: data['paymentDate']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: data['status']?.toString() ?? 'paid',
    );
  }

  factory RecurringPaymentModel.fromMap(Map<String, dynamic> map) {
    return RecurringPaymentModel.fromFirestore(map['id']?.toString() ?? '', map);
  }
}
