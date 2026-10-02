class BudgetAllocation {
  final String categoryId;
  final double allocatedAmount;

  const BudgetAllocation({
    required this.categoryId,
    required this.allocatedAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'allocatedAmount': allocatedAmount,
    };
  }

  factory BudgetAllocation.fromMap(Map<String, dynamic> map) {
    return BudgetAllocation(
      categoryId: map['categoryId']?.toString() ?? '',
      allocatedAmount: (map['allocatedAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  BudgetAllocation copyWith({String? categoryId, double? allocatedAmount}) {
    return BudgetAllocation(
      categoryId: categoryId ?? this.categoryId,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
    );
  }
}

class BudgetModel {
  final String? id;
  final String userId;
  final String budgetName;
  final String period; // daily | weekly | monthly | quarterly | yearly
  final double budgetAmount;
  final String status; // active | inactive
  final String startDate; // 'YYYY-MM-DD', auto-set at creation
  final String? endDate; // 'YYYY-MM-DD', optional
  final List<BudgetAllocation> categoryAllocations;
  final int createdDate;

  const BudgetModel({
    this.id,
    required this.userId,
    required this.budgetName,
    required this.period,
    required this.budgetAmount,
    this.status = 'active',
    required this.startDate,
    this.endDate,
    this.categoryAllocations = const [],
    required this.createdDate,
  });

  bool get isActive => status == 'active';

  double get totalAllocated {
    return categoryAllocations.fold(0.0, (sum, a) => sum + a.allocatedAmount);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'budgetName': budgetName,
      'period': period,
      'budgetAmount': budgetAmount,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
      'categoryAllocations': categoryAllocations.map((a) => a.toMap()).toList(),
      'createdDate': createdDate,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory BudgetModel.fromFirestore(String id, Map<String, dynamic> data) {
    final allocationsRaw = data['categoryAllocations'] as List<dynamic>? ?? [];

    return BudgetModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      budgetName: data['budgetName']?.toString() ?? '',
      period: data['period']?.toString() ?? 'monthly',
      budgetAmount: (data['budgetAmount'] as num?)?.toDouble() ?? 0,
      status: data['status']?.toString() ?? 'active',
      startDate: data['startDate']?.toString() ?? '',
      endDate: data['endDate']?.toString(),
      categoryAllocations: allocationsRaw
          .map((a) => BudgetAllocation.fromMap(Map<String, dynamic>.from(a as Map)))
          .toList(),
      createdDate: (data['createdDate'] as num?)?.toInt() ?? 0,
    );
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel.fromFirestore(map['id']?.toString() ?? '', map);
  }

  BudgetModel copyWith({
    String? id,
    String? userId,
    String? budgetName,
    String? period,
    double? budgetAmount,
    String? status,
    String? startDate,
    String? endDate,
    List<BudgetAllocation>? categoryAllocations,
    int? createdDate,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      budgetName: budgetName ?? this.budgetName,
      period: period ?? this.period,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryAllocations: categoryAllocations ?? this.categoryAllocations,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
