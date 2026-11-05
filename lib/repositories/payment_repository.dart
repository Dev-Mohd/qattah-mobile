import 'package:sqflite_sqlcipher/sqflite.dart';

import '../core/database.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final DatabaseManager _db = DatabaseManager.instance;

  Future<List<PaymentModel>> getByListId(String listId) async {
    final db = await _db.database;
    final maps = await db.query(
      'payments',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => PaymentModel.fromMap(m)).toList();
  }

  Future<void> insert(PaymentModel payment) async {
    final db = await _db.database;
    await db.insert(
      'payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(PaymentModel payment) async {
    final db = await _db.database;
    await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('payments', where: 'id = ?', whereArgs: [id]);
  }
}
