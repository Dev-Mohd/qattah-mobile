class MemberModel {
  final String id;
  final String listId;
  final String name;
  final double openingBalance;
  final bool isDefaultAttendee;
  final String createdAt;
  final String updatedAt;

  const MemberModel({
    required this.id,
    required this.listId,
    required this.name,
    required this.openingBalance,
    this.isDefaultAttendee = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    return MemberModel(
      id: map['id'] as String? ?? '',
      listId: map['list_id'] as String? ?? '',
      name: map['name'] as String? ?? 'بدون اسم',
      openingBalance: (map['opening_balance'] as num?)?.toDouble() ?? 0,
      isDefaultAttendee: (map['is_default_attendee'] as int?) != 0,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ?? map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'name': name,
      'opening_balance': openingBalance,
      'is_default_attendee': isDefaultAttendee ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  MemberModel copyWith({
    String? id,
    String? listId,
    String? name,
    double? openingBalance,
    bool? isDefaultAttendee,
    String? createdAt,
    String? updatedAt,
  }) {
    return MemberModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      openingBalance: openingBalance ?? this.openingBalance,
      isDefaultAttendee: isDefaultAttendee ?? this.isDefaultAttendee,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'MemberModel(id: $id, name: $name, balance: $openingBalance)';
}
