class SmsDraft {
  final String id;
  final String rawMessage;
  final String sender;
  final String type; // credit | debit
  final double amount;
  final String detectedDate; // 'YYYY-MM-DD'
  final int createdAt;

  const SmsDraft({
    required this.id,
    required this.rawMessage,
    required this.sender,
    required this.type,
    required this.amount,
    required this.detectedDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawMessage': rawMessage,
      'sender': sender,
      'type': type,
      'amount': amount,
      'detectedDate': detectedDate,
      'createdAt': createdAt,
    };
  }

  factory SmsDraft.fromJson(Map<String, dynamic> json) {
    return SmsDraft(
      id: json['id']?.toString() ?? '',
      rawMessage: json['rawMessage']?.toString() ?? '',
      sender: json['sender']?.toString() ?? '',
      type: json['type']?.toString() ?? 'debit',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      detectedDate: json['detectedDate']?.toString() ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}
