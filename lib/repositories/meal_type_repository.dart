import 'package:sqflite_sqlcipher/sqflite.dart';
import '../core/database.dart';
import '../models/meal_type_model.dart';

class MealTypeRepository {
  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<MealTypeModel>> getByListId(String listId) async {
    final db = await _db.database;
    final maps = await db.query(
      'meal_types',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => MealTypeModel.fromMap(m)).toList();
  }

  Future<void> insert(MealTypeModel mealType) async {
    final db = await _db.database;
    await db.insert('meal_types', mealType.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(MealTypeModel mealType) async {
    final db = await _db.database;
    await db.update('meal_types', mealType.toMap(),
        where: 'id = ?', whereArgs: [mealType.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('meal_types', where: 'id = ?', whereArgs: [id]);
  }
}
