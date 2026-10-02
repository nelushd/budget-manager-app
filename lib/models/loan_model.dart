class LoanModel {
  final String? id;
  final String userId;
  final String name;
  final String loanType; 
  final double totalAmount;
  final double paidAmount;
  final String startDate; 
  final String? dueDate; 
  final double? interestRate; 
  final int? termMonths; 
  final int? monthlyPaymentDay; 
  final double? customInstallmentAmount; 
  final String? accountId; 
  final String? nextDueDate; 
  final int createdDate;

  const LoanModel({
    this.id,
    required this.userId,
    required this.name,
    required this.loanType,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.startDate,
    this.dueDate,
    this.interestRate,
    this.termMonths,
    this.monthlyPaymentDay,
    this.customInstallmentAmount,
    this.accountId,
    this.note = '',
    this.nextDueDate,
    required this.createdDate,
  });

  bool get isBank => loanType == 'bank';
  bool get isPaid => paidAmount >= totalAmount;
  double get remaining => (totalAmount - paidAmount).clamp(0, double.infinity);
  double get progressPercent => totalAmount > 0 ? (paidAmount / totalAmount * 100).clamp(0, 100) : 0;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'loanType': loanType,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'startDate': startDate,
      'dueDate': dueDate,
      'interestRate': interestRate,
      'termMonths': termMonths,
      'monthlyPaymentDay': monthlyPaymentDay,
      'customInstallmentAmount': customInstallmentAmount,
      'accountId': accountId,
      'note': note,
      'nextDueDate': nextDueDate,
      'createdDate': createdDate,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  factory LoanModel.fromFirestore(String id, Map<String, dynamic> data) {
    return LoanModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      loanType: data['loanType']?.toString() ?? 'personal',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toDouble() ?? 0,
      startDate: data['startDate']?.toString() ?? '',
      dueDate: data['dueDate']?.toString(),
      interestRate: (data['interestRate'] as num?)?.toDouble(),
      termMonths: (data['termMonths'] as num?)?.toInt(),
      monthlyPaymentDay: (data['monthlyPaymentDay'] as num?)?.toInt(),
      customInstallmentAmount: (data['customInstallmentAmount'] as num?)?.toDouble(),
      accountId: data['accountId']?.toString(),
      note: data['note']?.toString() ?? '',
      nextDueDate: data['nextDueDate']?.toString(),
      createdDate: (data['createdDate'] as num?)?.toInt() ?? 0,
    );
  }

  factory LoanModel.fromMap(Map<String, dynamic> map) {
    return LoanModel.fromFirestore(map['id']?.toString() ?? '', map);
  }

  LoanModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? loanType,
    double? totalAmount,
    double? paidAmount,
    String? startDate,
    String? dueDate,
    double? interestRate,
    int? termMonths,
    int? monthlyPaymentDay,
    double? customInstallmentAmount,
    String? accountId,
    String? note,
    String? nextDueDate,
    int? createdDate,
  }) {
    return LoanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      loanType: loanType ?? this.loanType,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      interestRate: interestRate ?? this.interestRate,
      termMonths: termMonths ?? this.termMonths,
      monthlyPaymentDay: monthlyPaymentDay ?? this.monthlyPaymentDay,
      customInstallmentAmount: customInstallmentAmount ?? this.customInstallmentAmount,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
