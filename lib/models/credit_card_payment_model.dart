class CreditCardPaymentModel {
  final String? id;
  final String userId;
  final String cardId;
  final String accountId;
  final double amount;
  final String date;
  final String time;
  final int createdAt;

  const CreditCardPaymentModel({
    this.id,
    required this.userId,
    required this.cardId,
    required this.accountId,
    required this.amount,
    required this.date,
    required this.time,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'cardId': cardId,
      'accountId': accountId,
      'amount': amount,
      'date': date,
      'time': time,
      'createdAt': createdAt,
    };
  }

  factory CreditCardPaymentModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return CreditCardPaymentModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      cardId: data['cardId']?.toString() ?? '',
      accountId: data['accountId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      date: data['date']?.toString() ?? '',
      time: data['time']?.toString() ?? '',
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
