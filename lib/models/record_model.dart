class RecordModel {
  final String id;
  final String listId;
  final String? mealTypeId;
  final String mealName;
  final String date;
  final double totalAmount;
  final double perPerson;
  final String note;
  final String createdAt;
  final String updatedAt;

  const RecordModel({
    required this.id,
    required this.listId,
    this.mealTypeId,
    required this.mealName,
    required this.date,
    required this.totalAmount,
    required this.perPerson,
    this.note = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory RecordModel.fromMap(Map<String, dynamic> map) {
    return RecordModel(
      id: map['id'] as String,
      listId: map['list_id'] as String? ?? '',
      mealTypeId: map['meal_type_id'] as String?,
      mealName: map['meal_name'] as String? ?? 'وجبة',
      date: map['date'] as String? ?? DateTime.now().toIso8601String().split('T').first,
      totalAmount: ((map['total_amount'] ?? map['total_price']) as num?)?.toDouble() ?? 0,
      perPerson: ((map['per_person'] ?? map['per_person_price']) as num?)?.toDouble() ?? 0,
      note: map['note'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'meal_type_id': mealTypeId,
      'meal_name': mealName,
      'date': date,
      'total_amount': totalAmount,
      'per_person': perPerson,
      'note': note,
      'created_at': createdAt.isEmpty ? DateTime.now().toIso8601String() : createdAt,
      'updated_at': updatedAt.isEmpty ? DateTime.now().toIso8601String() : updatedAt,
    };
  }

  RecordModel copyWith({
    String? id,
    String? listId,
    String? mealTypeId,
    String? mealName,
    String? date,
    double? totalAmount,
    double? perPerson,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return RecordModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      mealTypeId: mealTypeId ?? this.mealTypeId,
      mealName: mealName ?? this.mealName,
      date: date ?? this.date,
      totalAmount: totalAmount ?? this.totalAmount,
      perPerson: perPerson ?? this.perPerson,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'RecordModel(id: $id, meal: $mealName, amount: $totalAmount)';
}
