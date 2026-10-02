class GoalModel {
  final String? id;
  final String userId;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final String targetDate; // 'YYYY-MM-DD'
  final String notes;
  final String iconName; // Material icon key, not emoji
  final String status; // active | completed
  final String? accountId;
  final int createdDate;

  const GoalModel({
    this.id,
    required this.userId,
    required this.goalName,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.targetDate,
    this.notes = '',
    this.iconName = 'flag',
    this.status = 'active',
    this.accountId,
    required this.createdDate,
  });

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'goalName': goalName,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate,
      'notes': notes,
      'iconName': iconName,
      'status': status,
      'accountId': accountId,
      'createdDate': createdDate,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory GoalModel.fromFirestore(String id, Map<String, dynamic> data) {
    return GoalModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      goalName: data['goalName']?.toString() ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0,
      targetDate: data['targetDate']?.toString() ?? '',
      notes: data['notes']?.toString() ?? '',
      iconName: data['iconName']?.toString() ?? 'flag',
      status: data['status']?.toString() ?? 'active',
      accountId: data['accountId']?.toString(),
      createdDate: (data['createdDate'] as num?)?.toInt() ?? 0,
    );
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel.fromFirestore(map['id']?.toString() ?? '', map);
  }

  GoalModel copyWith({
    String? id,
    String? userId,
    String? goalName,
    double? targetAmount,
    double? currentAmount,
    String? targetDate,
    String? notes,
    String? iconName,
    String? status,
    String? accountId,
    int? createdDate,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      goalName: goalName ?? this.goalName,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      notes: notes ?? this.notes,
      iconName: iconName ?? this.iconName,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
