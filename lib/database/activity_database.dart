import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recent_activity_model.dart';

/// SQLite database helper for local activity storage
class ActivityDatabase {
  static const String _databaseName = 'lejeepney_activities.db';
  static const int _databaseVersion = 2; // Bumped to clear old emoji data
  static const String _tableName = 'recent_activities';
  static const int _maxActivities = 50;

  static Database? _database;

  /// Get database instance (singleton)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create table schema
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        activity_type TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT,
        from_location TEXT,
        to_location TEXT,
        route_names TEXT,
        fare REAL,
        metadata TEXT,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Create indexes for better query performance
    await db.execute(
      'CREATE INDEX idx_created_at ON $_tableName (created_at DESC)',
    );
    await db.execute('CREATE INDEX idx_is_synced ON $_tableName (is_synced)');
    await db.execute(
      'CREATE INDEX idx_activity_type ON $_tableName (activity_type)',
    );
  }

  /// Handle database upgrades
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Clear old data when upgrading from v1 to v2 (removes emoji titles)
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS $_tableName');
      await _onCreate(db, newVersion);
    }
  }

  /// Insert a new activity
  static Future<int> insertActivity(RecentActivityModel activity) async {
    final db = await database;

    // Enforce max activities limit
    await _enforceLimit(db);

    return await db.insert(_tableName, activity.toSqlite());
  }

  /// Get all activities (sorted by created_at descending)
  static Future<List<RecentActivityModel>> getAllActivities({
    int? limit,
    String? activityType,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (activityType != null) {
      whereClause = 'activity_type = ?';
      whereArgs.add(activityType);
    }

    final rows = await db.query(
      _tableName,
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map((row) => RecentActivityModel.fromSqlite(row)).toList();
  }

  /// Get unsynced activities
  static Future<List<RecentActivityModel>> getUnsyncedActivities() async {
    final db = await database;

    final rows = await db.query(
      _tableName,
      where: 'is_synced = 0',
      orderBy: 'created_at ASC',
    );

    return rows.map((row) => RecentActivityModel.fromSqlite(row)).toList();
  }

  /// Mark activities as synced
  static Future<void> markAsSynced(
    List<int> localIds,
    List<int?> serverIds,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      for (int i = 0; i < localIds.length; i++) {
        await txn.update(
          _tableName,
          {
            'is_synced': 1,
            'server_id': serverIds.length > i ? serverIds[i] : null,
          },
          where: 'id = ?',
          whereArgs: [localIds[i]],
        );
      }
    });
  }

  /// Delete activity by local ID
  static Future<int> deleteActivity(int id) async {
    final db = await database;
    return await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Delete activity by server ID
  static Future<int> deleteActivityByServerId(int serverId) async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  /// Clear all activities
  static Future<int> clearAll() async {
    final db = await database;
    return await db.delete(_tableName);
  }

  /// Merge server activities with local (for pull sync)
  static Future<void> mergeServerActivities(
    List<RecentActivityModel> serverActivities,
  ) async {
    final db = await database;

    await db.transaction((txn) async {
      for (final activity in serverActivities) {
        if (activity.serverId != null) {
          // Check if already exists
          final existing = await txn.query(
            _tableName,
            where: 'server_id = ?',
            whereArgs: [activity.serverId],
          );

          if (existing.isEmpty) {
            // Insert new activity from server
            await txn.insert(_tableName, {
              ...activity.toSqlite(),
              'server_id': activity.serverId,
              'is_synced': 1,
            });
          }
        }
      }
    });

    // Enforce limit after merge
    await _enforceLimit(db);
  }

  /// Enforce maximum activities limit
  static Future<void> _enforceLimit(Database db) async {
    // Count total activities
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count >= _maxActivities) {
      // Delete oldest activities beyond limit
      final deleteCount = count - _maxActivities + 1;
      await db.rawDelete(
        '''
        DELETE FROM $_tableName 
        WHERE id IN (
          SELECT id FROM $_tableName 
          ORDER BY created_at ASC 
          LIMIT ?
        )
      ''',
        [deleteCount],
      );
    }
  }

  /// Cleanup old activities (older than 90 days)
  static Future<int> cleanupOldActivities() async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));

    return await db.delete(
      _tableName,
      where: 'created_at < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  /// Get activity count
  static Future<int> getActivityCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get unsynced count
  static Future<int> getUnsyncedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE is_synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Close database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
