import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database.dart';
import '../models/list_model.dart';

class ListRepository {
  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<ListModel>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('lists', orderBy: 'created_at DESC');
    return maps.map((m) => ListModel.fromMap(m)).toList();
  }

  Future<ListModel?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('lists', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ListModel.fromMap(maps.first);
  }

  Future<void> insert(ListModel list) async {
    final db = await _db.database;
    await db.insert('lists', list.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(ListModel list) async {
    final db = await _db.database;
    await db
        .update('lists', list.toMap(), where: 'id = ?', whereArgs: [list.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('lists', where: 'id = ?', whereArgs: [id]);
  }
}
