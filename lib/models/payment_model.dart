class PaymentModel {
  final String id;
  final String listId;
  final String? memberId;
  final String memberName;
  final double amount;
  final String note;
  final String createdAt;
  final String updatedAt;

  const PaymentModel({
    required this.id,
    required this.listId,
    required this.memberId,
    required this.memberName,
    required this.amount,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      id: map['id'] as String? ?? '',
      listId: map['list_id'] as String? ?? '',
      memberId: map['member_id'] as String?,
      memberName: map['member_name'] as String? ?? 'عضو محذوف',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String? ?? '',
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at'] as String? ??
          map['created_at'] as String? ??
          DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'member_id': memberId,
      'member_name': memberName,
      'amount': amount,
      'note': note,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  PaymentModel copyWith({
    String? id,
    String? listId,
    String? memberId,
    String? memberName,
    double? amount,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
