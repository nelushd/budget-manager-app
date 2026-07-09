class CategoryModel {
  final int? id;
  final String name;
  final String type; // income or expense
  final String iconName;
  final bool isDefault;
  final int createdAt;

  CategoryModel({
    this.id,
    required this.name,
    required this.type,
    required this.iconName,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'iconName': iconName,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      iconName: map['iconName'],
      isDefault: map['isDefault'] == 1,
      createdAt: map['createdAt'],
    );
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? type,
    String? iconName,
    bool? isDefault,
    int? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      iconName: iconName ?? this.iconName,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}