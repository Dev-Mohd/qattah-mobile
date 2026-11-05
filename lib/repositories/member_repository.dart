import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database.dart';
import '../models/member_model.dart';

class MemberRepository {
  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<MemberModel>> getByListId(String listId) async {
    final db = await _db.database;
    final maps = await db.query(
      'members',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => MemberModel.fromMap(m)).toList();
  }

  Future<MemberModel?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('members', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return MemberModel.fromMap(maps.first);
  }

  Future<void> insert(MemberModel member) async {
    final db = await _db.database;
    await db.insert('members', member.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(MemberModel member) async {
    final db = await _db.database;
    await db.update('members', member.toMap(),
        where: 'id = ?', whereArgs: [member.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('members', where: 'id = ?', whereArgs: [id]);
  }
}
