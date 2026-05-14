import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/toilet_record.dart';
import '../models/profile_model.dart';
import '../models/season.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'la_le_me.db';
  static const int _dbVersion = 3;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE toilet_records (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        duration INTEGER,
        bristol_type INTEGER,
        color INTEGER,
        smoothness INTEGER,
        is_work_hours INTEGER DEFAULT 0,
        is_paid_poop INTEGER DEFAULT 0,
        location_hash TEXT,
        note TEXT,
        mood TEXT,
        created_at INTEGER DEFAULT 0,
        updated_at INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        sync_uuid TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname TEXT,
        avatar_base64 TEXT,
        gender INTEGER DEFAULT 0,
        birth_year INTEGER,
        height_cm REAL,
        weight_kg REAL,
        chest_cm REAL,
        waist_cm REAL,
        hip_cm REAL,
        job_type INTEGER DEFAULT 0,
        work_start_hour INTEGER,
        work_end_hour INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE season_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        season TEXT NOT NULL,
        final_score INTEGER DEFAULT 0,
        final_rank TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_reports (
        id TEXT PRIMARY KEY,
        result_json TEXT NOT NULL,
        generated_at INTEGER NOT NULL,
        valid_until INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_records_timestamp ON toilet_records(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_records_type ON toilet_records(type)',
    );
    await db.execute(
      'CREATE INDEX idx_records_sync ON toilet_records(is_synced)',
    );

    await db.insert('user_profile', {'id': 1});

    await db.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        unlocked_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_achievements_synced ON achievements(synced)',
    );
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    for (int v = oldVersion + 1; v <= newVersion; v++) {
      switch (v) {
        case 2:
          await db.execute('''
            CREATE TABLE achievements (
              id TEXT PRIMARY KEY,
              unlocked_at INTEGER NOT NULL,
              synced INTEGER DEFAULT 0
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_achievements_synced ON achievements(synced)',
          );
          break;
        case 3:
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN work_start_hour INTEGER',
          );
          await db.execute(
            'ALTER TABLE user_profile ADD COLUMN work_end_hour INTEGER',
          );
          break;
      }
    }
  }

  static Future<String> insertRecord(ToiletRecord record) async {
    final db = await database;
    await db.insert('toilet_records', record.toMap());
    return record.id;
  }

  static Future<List<ToiletRecord>> getRecords({
    int? limit,
    int? offset,
    RecordType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String where = '1=1';
    List<dynamic> whereArgs = [];

    if (type != null) {
      where += ' AND type = ?';
      whereArgs.add(type.index);
    }
    if (startDate != null) {
      where += ' AND timestamp >= ?';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      where += ' AND timestamp <= ?';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'toilet_records',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => ToiletRecord.fromMap(m)).toList();
  }

  static Future<List<ToiletRecord>> getRecentRecords({int days = 7}) async {
    DateTime startDate = DateTime.now().subtract(Duration(days: days));
    return getRecords(startDate: startDate);
  }

  static Future<List<ToiletRecord>> getTodayRecords() async {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    return getRecords(startDate: startOfDay, endDate: endOfDay);
  }

  static Future<int> updateRecord(ToiletRecord record) async {
    final db = await database;
    return db.update(
      'toilet_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  static Future<int> deleteRecord(String id) async {
    final db = await database;
    return db.delete('toilet_records', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<ToiletRecord>> getUnsyncedRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'toilet_records',
      where: 'is_synced = 0',
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ToiletRecord.fromMap(m)).toList();
  }

  static Future<void> markRecordSynced(String id, String syncUuid) async {
    final db = await database;
    await db.update(
      'toilet_records',
      {'is_synced': 1, 'sync_uuid': syncUuid},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> getTodayBigCount() async {
    final records = await getTodayRecords();
    return records.where((r) => r.type == RecordType.big).length;
  }

  static Future<int> getTodaySmallCount() async {
    final records = await getTodayRecords();
    return records.where((r) => r.type == RecordType.small).length;
  }

  static Future<int> getTotalRecordCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM toilet_records');
    return result.first['count'] as int;
  }

  static Future<ProfileModel> getProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (maps.isEmpty) return ProfileModel();
    return ProfileModel.fromMap(maps.first);
  }

  static Future<void> saveProfile(ProfileModel profile) async {
    final db = await database;
    await db.update('user_profile', profile.toMap(),
        where: 'id = ?', whereArgs: [1]);
  }

  static Future<void> saveSeasonHistory(SeasonHistory history) async {
    final db = await database;
    await db.insert('season_history', history.toMap());
  }

  static Future<List<SeasonHistory>> getSeasonHistories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'season_history',
      orderBy: 'season DESC',
    );
    return maps.map((m) => SeasonHistory.fromMap(m)).toList();
  }

  static Future<void> saveAIReport({
    required String reportId,
    required Map<String, dynamic> result,
    required DateTime validUntil,
  }) async {
    final db = await database;
    await db.insert('ai_reports', {
      'id': reportId,
      'result_json': jsonEncode(result),
      'generated_at': DateTime.now().millisecondsSinceEpoch,
      'valid_until': validUntil.millisecondsSinceEpoch,
    });
  }

  static Future<Map<String, dynamic>?> getLatestAIReport() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ai_reports',
      orderBy: 'generated_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final map = Map<String, dynamic>.from(maps.first);
    if (map.containsKey('result_json') && map['result_json'] is String) {
      try {
        map['result_json'] = jsonDecode(map['result_json'] as String);
      } catch (_) {}
    }
    return map;
  }

  static Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  static Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> clearAllData() async {
    final db = await database;
    await db.delete('toilet_records');
    await db.delete('ai_reports');
    await db.delete('season_history');
    await db.delete('app_settings');
    await db.delete('achievements');
    await db.update('user_profile', {'nickname': null, 'avatar_base64': null});
  }

  static Future<void> deleteDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, _dbName);
    databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
