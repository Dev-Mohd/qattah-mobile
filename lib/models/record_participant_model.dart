class RecordParticipantModel {
  final String id;
  final String recordId;
  final String? memberId;
  final String memberName;
  final double share;
  final String createdAt;
  final String updatedAt;

  const RecordParticipantModel({
    required this.id,
    required this.recordId,
    this.memberId,
    required this.memberName,
    required this.share,
    this.createdAt = '',
    this.updatedAt = '',
  });

  factory RecordParticipantModel.fromMap(Map<String, dynamic> map) {
    return RecordParticipantModel(
      id: map['id'] as String,
      recordId: map['record_id'] as String? ?? '',
      memberId: map['member_id'] as String?,
      memberName: map['member_name'] as String? ?? 'عضو محذوف',
      share: (map['share'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'record_id': recordId,
      'member_id': memberId,
      'member_name': memberName,
      'share': share,
      'share_amount': share,
      'created_at': createdAt.isEmpty ? DateTime.now().toIso8601String() : createdAt,
      'updated_at': updatedAt.isEmpty ? DateTime.now().toIso8601String() : updatedAt,
    };
  }

  RecordParticipantModel copyWith({
    String? id,
    String? recordId,
    String? memberId,
    String? memberName,
    double? share,
    String? createdAt,
    String? updatedAt,
  }) {
    return RecordParticipantModel(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      memberId: memberId ?? this.memberId,
      memberName: memberName ?? this.memberName,
      share: share ?? this.share,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'RecordParticipantModel(recordId: $recordId, name: $memberName, share: $share)';
}
