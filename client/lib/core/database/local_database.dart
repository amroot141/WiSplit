import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wisplit_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createAdditionalTables(db);
      },
      onOpen: (db) async {
        await _createAdditionalTables(db);
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Cached Expenses Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_expenses (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        paid_by TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        description TEXT NOT NULL,
        split_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        splits_json TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 2. Offline Sync Queue (FIFO queue for offline operations)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        temp_id TEXT NOT NULL,
        item_type TEXT NOT NULL,
        action TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'PENDING'
      )
    ''');

    // 3. Cached Personal Ledger Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_personal_ledger (
        id TEXT PRIMARY KEY,
        creditor_id TEXT NOT NULL,
        debtor_id TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        description TEXT NOT NULL,
        status TEXT NOT NULL,
        settled_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await _createAdditionalTables(db);

    // Indexes for fast querying
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cached_exp_group ON cached_expenses (group_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cached_ledger_status ON cached_personal_ledger (status)');
  }

  Future<void> _createAdditionalTables(Database db) async {
    // 4. Cached Groups Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT 'USD',
        created_by TEXT NOT NULL,
        members_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 5. User Session Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_session (
        id TEXT PRIMARY KEY,
        email TEXT NOT NULL,
        full_name TEXT NOT NULL,
        access_token TEXT,
        refresh_token TEXT,
        currency TEXT NOT NULL DEFAULT 'USD',
        is_logged_in INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
