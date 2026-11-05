class MealTypeModel {
  final String id;
  final String listId;
  final String name;
  final double defaultPrice;
  final String createdAt;
  final String updatedAt;

  const MealTypeModel({
    required this.id,
    required this.listId,
    required this.name,
    required this.defaultPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealTypeModel.fromMap(Map<String, dynamic> map) {
    return MealTypeModel(
      id: map['id'] as String? ?? '',
      listId: map['list_id'] as String? ?? '',
      name: map['name'] as String? ?? 'بدون اسم',
      defaultPrice: (map['default_price'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'name': name,
      'default_price': defaultPrice,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  MealTypeModel copyWith({
    String? id,
    String? listId,
    String? name,
    double? defaultPrice,
    String? createdAt,
    String? updatedAt,
  }) {
    return MealTypeModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'MealTypeModel(id: $id, name: $name, price: $defaultPrice)';
}
