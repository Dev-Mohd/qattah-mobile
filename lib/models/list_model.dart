class ListModel {
  final String id;
  final String name;
  final String color;
  final String createdAt;
  final String updatedAt;

  const ListModel({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ListModel.fromMap(Map<String, dynamic> map) {
    return ListModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'بدون اسم',
      color: map['color'] as String? ?? '#2563EB',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  ListModel copyWith({
    String? id,
    String? name,
    String? color,
    String? createdAt,
    String? updatedAt,
  }) {
    return ListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'ListModel(id: $id, name: $name)';
}
