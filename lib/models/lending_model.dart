class LendingModel {
  final String? id;
  final String userId;
  final String name;
  final double totalAmount;
  final double receivedAmount;
  final String startDate; // 'YYYY-MM-DD'
  final String? dueDate;
  final String? accountId; 
  final String note;
  final int createdDate;

  const LendingModel({
    this.id,
    required this.userId,
    required this.name,
    required this.totalAmount,
    this.receivedAmount = 0,
    required this.startDate,
    this.dueDate,
    this.accountId,
    this.note = '',
    required this.createdDate,
  });

  bool get isSettled => receivedAmount >= totalAmount;
  double get remaining => (totalAmount - receivedAmount).clamp(0, double.infinity);
  double get progressPercent => totalAmount > 0 ? (receivedAmount / totalAmount * 100).clamp(0, 100) : 0;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'totalAmount': totalAmount,
      'receivedAmount': receivedAmount,
      'startDate': startDate,
      'dueDate': dueDate,
      'accountId': accountId,
      'note': note,
      'createdDate': createdDate,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory LendingModel.fromFirestore(String id, Map<String, dynamic> data) {
    return LendingModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      receivedAmount: (data['receivedAmount'] as num?)?.toDouble() ?? 0,
      startDate: data['startDate']?.toString() ?? '',
      dueDate: data['dueDate']?.toString(),
      accountId: data['accountId']?.toString(),
      note: data['note']?.toString() ?? '',
      createdDate: (data['createdDate'] as num?)?.toInt() ?? 0,
    );
  }

  factory LendingModel.fromMap(Map<String, dynamic> map) {
    return LendingModel.fromFirestore(map['id']?.toString() ?? '', map);
  }

  LendingModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? totalAmount,
    double? receivedAmount,
    String? startDate,
    String? dueDate,
    String? accountId,
    String? note,
    int? createdDate,
  }) {
    return LendingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      totalAmount: totalAmount ?? this.totalAmount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
