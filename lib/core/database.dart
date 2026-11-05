import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as plain;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import 'database_key_service.dart';

class DatabaseManager {
  static const String _encryptedDatabaseName = 'qattah_secure.db';
  static const String _legacyDatabaseName = 'qattah.db';
  static const List<String> _tables = [
    'lists',
    'members',
    'meal_types',
    'records',
    'record_participants',
    'payments',
  ];

  static cipher.Database? _database;
  static bool _schemaEnsured = false;
  static final DatabaseManager instance = DatabaseManager._internal();

  DatabaseManager._internal();

  Future<cipher.Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    if (!_schemaEnsured) {
      await _ensureSchema(_database!);
      _schemaEnsured = true;
    }
    return _database!;
  }

  Future<cipher.Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final encryptedPath = join(documentsDirectory.path, _encryptedDatabaseName);
    final legacyPath = join(documentsDirectory.path, _legacyDatabaseName);
    final key = await const DatabaseKeyService().getOrCreateKey();

    final db = await cipher.openDatabase(
      encryptedPath,
      password: key,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        if (!_schemaEnsured) {
          await _ensureSchema(db);
          _schemaEnsured = true;
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    if (await _shouldMigrateLegacyDatabase(legacyPath, db)) {
      await _backupEncryptedDatabase(encryptedPath);
      await _migrateLegacyDatabase(legacyPath, db);
    }

    return db;
  }

  Future<void> _onCreate(cipher.Database db, int version) async {
    await db.execute('''
      CREATE TABLE lists (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY NOT NULL,
        list_id TEXT NOT NULL,
        name TEXT NOT NULL,
        emoji TEXT NOT NULL DEFAULT '👤',
        is_active INTEGER NOT NULL DEFAULT 1,
        opening_balance REAL NOT NULL DEFAULT 0,
        is_default_attendee INTEGER NOT NULL DEFAULT 1,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_types (
        id TEXT PRIMARY KEY NOT NULL,
        list_id TEXT NOT NULL,
        name TEXT NOT NULL,
        default_price REAL NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY NOT NULL,
        list_id TEXT NOT NULL,
        meal_type_id TEXT,
        meal_name TEXT NOT NULL,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        total_price REAL NOT NULL DEFAULT 0,
        per_person REAL NOT NULL,
        price_per_person REAL NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        notes TEXT,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE,
        FOREIGN KEY (meal_type_id) REFERENCES meal_types(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE record_participants (
        id TEXT PRIMARY KEY NOT NULL,
        record_id TEXT NOT NULL,
        member_id TEXT,
        member_name TEXT NOT NULL,
        share REAL NOT NULL,
        is_present INTEGER NOT NULL DEFAULT 1,
        share_amount REAL NOT NULL DEFAULT 0,
        is_paid INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL DEFAULT '',
        updated_at TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id TEXT PRIMARY KEY NOT NULL,
        list_id TEXT NOT NULL,
        member_id TEXT,
        member_name TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        sync_status TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_records_list_date ON records(list_id, date)');
    await db.execute(
        'CREATE INDEX idx_participants_record ON record_participants(record_id)');
    await db.execute(
        'CREATE INDEX idx_participants_member ON record_participants(member_id)');
    await db.execute('CREATE INDEX idx_payments_list ON payments(list_id)');
    await db.execute('CREATE INDEX idx_payments_member ON payments(member_id)');
  }

  Future<void> _onUpgrade(
      cipher.Database db, int oldVersion, int newVersion) async {
    await _ensureSchema(db);
    _schemaEnsured = true;
  }

  Future<void> _ensureSchema(cipher.Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY NOT NULL,
        list_id TEXT NOT NULL,
        member_id TEXT,
        member_name TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (list_id) REFERENCES lists(id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE SET NULL
      )
    ''');
    await _ensureColumn(
      db,
      table: 'lists',
      column: 'color',
      definition: "TEXT NOT NULL DEFAULT '#2563EB'",
    );
    await _ensureColumn(
      db,
      table: 'lists',
      column: 'icon',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'lists',
      column: 'is_archived',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'lists',
      column: 'sync_status',
      definition: "TEXT NOT NULL DEFAULT 'local'",
    );
    await _ensureColumn(
      db,
      table: 'lists',
      column: 'created_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'lists',
      column: 'updated_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'emoji',
      definition: "TEXT NOT NULL DEFAULT '👤'",
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'is_active',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'opening_balance',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'is_default_attendee',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'sync_status',
      definition: "TEXT NOT NULL DEFAULT 'local'",
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'created_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'members',
      column: 'updated_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'meal_types',
      column: 'default_price',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'meal_types',
      column: 'sync_status',
      definition: "TEXT NOT NULL DEFAULT 'local'",
    );
    await _ensureColumn(
      db,
      table: 'meal_types',
      column: 'created_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'meal_types',
      column: 'updated_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'meal_type_id',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'meal_name',
      definition: "TEXT NOT NULL DEFAULT 'وجبة'",
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'total_amount',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'total_price',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'per_person',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'price_per_person',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'note',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'notes',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'sync_status',
      definition: "TEXT NOT NULL DEFAULT 'local'",
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'created_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'records',
      column: 'updated_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'member_name',
      definition: "TEXT NOT NULL DEFAULT 'عضو'",
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'share',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'is_present',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'share_amount',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'is_paid',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'sync_status',
      definition: "TEXT NOT NULL DEFAULT 'local'",
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'created_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'record_participants',
      column: 'updated_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'payments',
      column: 'sync_status',
      definition: "TEXT NOT NULL DEFAULT 'local'",
    );
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_records_list_date ON records(list_id, date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_participants_record ON record_participants(record_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_participants_member ON record_participants(member_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_list ON payments(list_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_member ON payments(member_id)');
  }

  Future<void> _ensureColumn(
    cipher.Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((c) => c['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _migrateLegacyDatabase(
    String legacyPath,
    cipher.Database encryptedDb,
  ) async {
    plain.Database? legacyDb;
    try {
      legacyDb = await plain.openDatabase(legacyPath, readOnly: true);
      final data = <String, List<Map<String, Object?>>>{};
      for (final table in _tables) {
        data[table] = await legacyDb.query(table);
      }
      final targetColumns = <String, Set<String>>{};
      for (final table in _tables) {
        targetColumns[table] = await _tableColumnNames(encryptedDb, table);
      }

      await encryptedDb.transaction((txn) async {
        for (final table in _tables.reversed) {
          await txn.delete(table);
        }
        for (final table in _tables) {
          for (final row in data[table] ?? const <Map<String, Object?>>[]) {
            await txn.insert(
              table,
              _filterColumns(row, targetColumns[table] ?? const {}),
              conflictAlgorithm: cipher.ConflictAlgorithm.replace,
            );
          }
        }
      });

      await legacyDb.close();
      legacyDb = null;
      await _moveLegacyDatabaseToBackup(legacyPath);
    } finally {
      await legacyDb?.close();
    }
  }

  Future<bool> _shouldMigrateLegacyDatabase(
    String legacyPath,
    cipher.Database encryptedDb,
  ) async {
    if (!File(legacyPath).existsSync()) return false;

    plain.Database? legacyDb;
    try {
      legacyDb = await plain.openDatabase(legacyPath, readOnly: true);
      final legacyRows = await _userRowCount(legacyDb);
      final encryptedRows = await _userRowCount(encryptedDb);

      return legacyRows > 0 && legacyRows > encryptedRows;
    } finally {
      await legacyDb?.close();
    }
  }

  Future<int> _userRowCount(dynamic db) async {
    var total = 0;
    for (final table in _tables) {
      final result = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
      total += (result.first['count'] as int?) ?? 0;
    }
    return total;
  }

  Future<Set<String>> _tableColumnNames(dynamic db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)') as List;
    return {
      for (final row in rows)
        (Map<String, Object?>.from(row as Map)['name'] as String)
    };
  }

  Map<String, Object?> _filterColumns(
    Map<String, Object?> row,
    Set<String> columns,
  ) {
    return Map.fromEntries(
        row.entries.where((entry) => columns.contains(entry.key)));
  }

  Future<void> _backupEncryptedDatabase(String encryptedPath) async {
    final encryptedFile = File(encryptedPath);
    if (!encryptedFile.existsSync()) return;

    final directory = dirname(encryptedPath);
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupPath =
        join(directory, 'qattah_secure_before_restore_$timestamp.db');
    await encryptedFile.copy(backupPath);
  }

  Future<void> _moveLegacyDatabaseToBackup(String legacyPath) async {
    final legacyFile = File(legacyPath);
    if (!legacyFile.existsSync()) return;

    final directory = dirname(legacyPath);
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupPath = join(directory, 'qattah_plain_backup_$timestamp.db');
    await legacyFile.rename(backupPath);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    _schemaEnsured = false;
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete('payments');
    await db.delete('record_participants');
    await db.delete('records');
    await db.delete('meal_types');
    await db.delete('members');
    await db.delete('lists');
  }
}
