import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'database.dart';

class BackupService {
  static const int backupVersion = 1;

  static const List<String> _tables = [
    'lists',
    'members',
    'meal_types',
    'records',
    'record_participants',
    'payments',
  ];

  const BackupService();

  Future<File> exportJson() async {
    final db = await DatabaseManager.instance.database;
    final data = <String, dynamic>{
      'app': 'qattah',
      'version': backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': <String, dynamic>{},
    };

    final tables = data['tables'] as Map<String, dynamic>;
    for (final table in _tables) {
      tables[table] = await db.query(table);
    }

    final dir = await getTemporaryDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File(p.join(dir.path, 'qattah-backup-$timestamp.json'));
    const encoder = JsonEncoder.withIndent('  ');
    return file.writeAsString(encoder.convert(data), flush: true);
  }

  Future<void> importJsonFile(File file) async {
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupException('ملف النسخة الاحتياطية غير صحيح');
    }
    await importJson(decoded);
  }

  Future<void> importJson(Map<String, dynamic> backup) async {
    if (backup['app'] != 'qattah' || backup['tables'] is! Map) {
      throw const BackupException('هذا الملف ليس نسخة احتياطية من تطبيق قطه');
    }

    final tables = Map<String, dynamic>.from(backup['tables'] as Map);
    for (final table in _tables) {
      final rows = tables[table];
      if (rows != null && rows is! List) {
        throw BackupException('بيانات جدول $table غير صحيحة');
      }
    }

    final db = await DatabaseManager.instance.database;
    await db.transaction((txn) async {
      await _deleteAll(txn);
      for (final table in _tables) {
        final rows = (tables[table] as List?) ?? const [];
        for (final row in rows) {
          if (row is! Map) continue;
          await txn.insert(
            table,
            Map<String, Object?>.from(row),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> deleteAll() async {
    await DatabaseManager.instance.deleteAll();
  }

  Future<void> _deleteAll(Transaction txn) async {
    for (final table in _tables.reversed) {
      await txn.delete(table);
    }
  }
}

class BackupException implements Exception {
  final String message;

  const BackupException(this.message);

  @override
  String toString() => message;
}
