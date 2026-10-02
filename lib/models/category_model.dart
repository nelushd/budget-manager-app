class CategoryModel {
  final String? id;
  final String userId;
  final String name;
  final String type;
  final String iconName;
  final bool isDefault;
  final int createdAt;

  const CategoryModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.iconName,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'type': type,
      'iconName': iconName,
      'isDefault': isDefault,
      'createdAt': createdAt,
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  factory CategoryModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return CategoryModel(
      id: id,
      userId: data['userId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      type: data['type']?.toString() ?? 'expense',
      iconName: data['iconName']?.toString() ?? 'category',
      isDefault: data['isDefault'] == true,
      createdAt: (data['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel.fromFirestore(
      map['id']?.toString() ?? '',
      map,
    );
  }

  CategoryModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? iconName,
    bool? isDefault,
    int? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}