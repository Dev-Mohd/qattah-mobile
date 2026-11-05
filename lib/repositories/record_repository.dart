import '../core/database.dart';
import '../models/record_model.dart';
import '../models/record_participant_model.dart';

class RecordRepository {
  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<RecordModel>> getByListId(String listId) async {
    final db = await _db.database;
    final maps = await db.query(
      'records',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => RecordModel.fromMap(m)).toList();
  }

  Future<List<RecordParticipantModel>> getParticipants(String recordId) async {
    final db = await _db.database;
    final maps = await db.query(
      'record_participants',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    return maps.map((m) => RecordParticipantModel.fromMap(m)).toList();
  }

  Future<List<RecordParticipantModel>> getAllParticipantsByListId(String listId) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT rp.* FROM record_participants rp
      INNER JOIN records r ON rp.record_id = r.id
      WHERE r.list_id = ?
    ''', [listId]);
    return maps.map((m) => RecordParticipantModel.fromMap(m)).toList();
  }

  Future<void> createRecordWithParticipants(
    RecordModel record,
    List<RecordParticipantModel> participants,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final recordColumns = await _tableColumns(txn, 'records');
      final participantColumns = await _tableColumns(txn, 'record_participants');

      await txn.insert('records', _forColumns(record.toMap(), recordColumns));
      for (final p in participants) {
        await txn.insert('record_participants', _forColumns(p.toMap(), participantColumns));
      }
    });
  }

  Future<void> updateRecordWithParticipants(
    RecordModel record,
    List<RecordParticipantModel> participants,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final recordColumns = await _tableColumns(txn, 'records');
      final participantColumns = await _tableColumns(txn, 'record_participants');

      await txn.update(
        'records',
        _forColumns(record.toMap(), recordColumns),
        where: 'id = ?',
        whereArgs: [record.id],
      );
      await txn.delete('record_participants', where: 'record_id = ?', whereArgs: [record.id]);
      for (final p in participants) {
        await txn.insert('record_participants', _forColumns(p.toMap(), participantColumns));
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<_DbColumn>> _tableColumns(dynamic db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)') as List;
    return [
      for (final row in rows)
        _DbColumn.fromMap(Map<String, Object?>.from(row as Map)),
    ];
  }

  Map<String, dynamic> _forColumns(Map<String, dynamic> map, List<_DbColumn> columns) {
    final names = columns.map((c) => c.name).toSet();
    final values = Map.fromEntries(map.entries.where((entry) => names.contains(entry.key)));

    for (final column in columns) {
      if (values.containsKey(column.name) || !column.requiresValue) continue;
      values[column.name] = _defaultFor(column);
    }

    return values;
  }

  Object _defaultFor(_DbColumn column) {
    final name = column.name.toLowerCase();
    final type = column.type.toUpperCase();

    if (name.endsWith('_at') || name == 'date') {
      return DateTime.now().toIso8601String();
    }
    if (name.contains('price') ||
        name.contains('amount') ||
        name.contains('total') ||
        name.contains('share') ||
        name.contains('balance') ||
        type.contains('REAL') ||
        type.contains('INT') ||
        type.contains('NUM')) {
      return 0;
    }
    return '';
  }
}

class _DbColumn {
  final String name;
  final String type;
  final bool notNull;
  final bool primaryKey;
  final Object? defaultValue;

  const _DbColumn({
    required this.name,
    required this.type,
    required this.notNull,
    required this.primaryKey,
    required this.defaultValue,
  });

  bool get requiresValue => notNull && !primaryKey && defaultValue == null;

  factory _DbColumn.fromMap(Map<String, Object?> map) {
    return _DbColumn(
      name: map['name'] as String,
      type: map['type'] as String? ?? '',
      notNull: map['notnull'] == 1,
      primaryKey: map['pk'] == 1,
      defaultValue: map['dflt_value'],
    );
  }
}
