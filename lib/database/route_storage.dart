// Route Storage - Persistent SQLite storage for jeepney routes
// Enables offline-first routing: routes load from disk instantly,
// then sync with server in the background.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/jeepney_route.dart';

/// Persistent storage for jeepney routes using SQLite.
///
/// Routes are stored as complete JSON payloads so they can be
/// reconstructed with full path coordinates and waypoints.
class RouteStorage {
  static const String _databaseName = 'lejeepney_routes.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'routes';
  static const String _metaTable = 'sync_meta';

  static Database? _database;

  // ========== DATABASE INITIALIZATION ==========

  /// Get database instance (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    debugPrint('[RouteStorage] Opening database at: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create table schema
  Future<void> _onCreate(Database db, int version) async {
    // Main routes table
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        route_number TEXT NOT NULL DEFAULT '',
        terminal TEXT,
        destination TEXT,
        distance_km REAL,
        base_fare REAL NOT NULL DEFAULT 13.0,
        color TEXT,
        status TEXT NOT NULL DEFAULT 'available',
        path_json TEXT NOT NULL DEFAULT '[]',
        waypoints_json TEXT,
        description TEXT
      )
    ''');

    // Sync metadata table
    await db.execute('''
      CREATE TABLE $_metaTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create index on status for filtered queries
    await db.execute('CREATE INDEX idx_routes_status ON $_tableName (status)');

    debugPrint('[RouteStorage] Database created (v$version)');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
      '[RouteStorage] Upgrading database from v$oldVersion to v$newVersion',
    );

    // Drop and recreate for now (routes are re-fetched from API)
    await db.execute('DROP TABLE IF EXISTS $_tableName');
    await db.execute('DROP TABLE IF EXISTS $_metaTable');
    await _onCreate(db, newVersion);
  }

  // ========== SAVE ROUTES ==========

  /// Save all routes to disk (batch insert/replace).
  ///
  /// Uses a transaction with INSERT OR REPLACE for atomicity.
  /// Stores path and waypoints as JSON TEXT columns.
  Future<void> saveRoutes(List<JeepneyRoute> routes) async {
    if (routes.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing routes
      await txn.delete(_tableName);

      // Batch insert all routes
      final batch = txn.batch();
      for (final route in routes) {
        batch.insert(
          _tableName,
          _routeToRow(route),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      // Update sync timestamp
      await txn.insert(_metaTable, {
        'key': 'last_sync',
        'value': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert(_metaTable, {
        'key': 'route_count',
        'value': routes.length.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });

    stopwatch.stop();
    debugPrint(
      '[RouteStorage] Saved ${routes.length} routes to disk '
      'in ${stopwatch.elapsedMilliseconds}ms',
    );
  }

  // ========== LOAD ROUTES ==========

  /// Load all routes from disk.
  ///
  /// Returns an empty list if no routes are stored.
  /// Routes are sorted alphabetically by name.
  Future<List<JeepneyRoute>> loadRoutes() async {
    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final rows = await db.query(_tableName, orderBy: 'name ASC');

      if (rows.isEmpty) {
        debugPrint('[RouteStorage] No routes stored on disk');
        return [];
      }

      final routes = rows.map(_rowToRoute).toList();

      stopwatch.stop();
      debugPrint(
        '[RouteStorage] Loaded ${routes.length} routes from disk '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );

      return routes;
    } catch (e) {
      debugPrint('[RouteStorage] Error loading routes: $e');
      return [];
    }
  }

  /// Get a single route by ID from disk.
  Future<JeepneyRoute?> getRoute(int id) async {
    try {
      final db = await database;
      final rows = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return _rowToRoute(rows.first);
    } catch (e) {
      debugPrint('[RouteStorage] Error getting route $id: $e');
      return null;
    }
  }

  // ========== METADATA ==========

  /// Check if any routes are stored on disk.
  Future<bool> hasStoredRoutes() async {
    try {
      final db = await database;
      final result = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
      );
      return (result ?? 0) > 0;
    } catch (e) {
      debugPrint('[RouteStorage] Error checking stored routes: $e');
      return false;
    }
  }

  /// Get the number of stored routes.
  Future<int> routeCount() async {
    try {
      final db = await database;
      return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
          ) ??
          0;
    } catch (e) {
      return 0;
    }
  }

  /// Get the timestamp of the last successful sync.
  Future<DateTime?> getLastSyncTime() async {
    try {
      final db = await database;
      final rows = await db.query(
        _metaTable,
        where: 'key = ?',
        whereArgs: ['last_sync'],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return DateTime.tryParse(rows.first['value'] as String);
    } catch (e) {
      return null;
    }
  }

  // ========== CLEANUP ==========

  /// Delete all stored routes.
  Future<void> deleteAllRoutes() async {
    try {
      final db = await database;
      await db.delete(_tableName);
      await db.delete(_metaTable);
      debugPrint('[RouteStorage] All routes deleted from disk');
    } catch (e) {
      debugPrint('[RouteStorage] Error deleting routes: $e');
    }
  }

  /// Close the database (call on app dispose).
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // ========== SERIALIZATION ==========

  /// Convert a JeepneyRoute to a database row map.
  Map<String, dynamic> _routeToRow(JeepneyRoute route) {
    // Encode path as JSON array of [lat, lng] pairs
    final pathJson = jsonEncode(
      route.path.map((p) => [p.latitude, p.longitude]).toList(),
    );

    // Encode waypoints as JSON array
    final waypointsJson = route.waypoints.isNotEmpty
        ? jsonEncode(route.waypoints.map((w) => w.toJson()).toList())
        : null;

    return {
      'id': route.id,
      'name': route.name,
      'route_number': route.routeNumber,
      'terminal': route.terminal,
      'destination': route.destination,
      'distance_km': route.distanceKm,
      'base_fare': route.baseFare,
      'color': route.color,
      'status': route.status,
      'path_json': pathJson,
      'waypoints_json': waypointsJson,
      'description': route.description,
    };
  }

  /// Convert a database row map to a JeepneyRoute.
  JeepneyRoute _rowToRoute(Map<String, dynamic> row) {
    // Reconstruct using the existing fromJson factory
    // by building a JSON map that matches the API format.
    final jsonMap = <String, dynamic>{
      'id': row['id'],
      'name': row['name'],
      'route_number': row['route_number'],
      'terminal': row['terminal'],
      'destination': row['destination'],
      'distance': row['distance_km'],
      'base_fare': row['base_fare'],
      'color': row['color'],
      'status': row['status'],
      'description': row['description'],
    };

    // Decode path JSON
    try {
      final pathJson = row['path_json'] as String?;
      if (pathJson != null && pathJson.isNotEmpty) {
        jsonMap['path'] = jsonDecode(pathJson);
      }
    } catch (e) {
      debugPrint(
        '[RouteStorage] Error decoding path for route ${row['id']}: $e',
      );
      jsonMap['path'] = [];
    }

    // Decode waypoints JSON
    try {
      final waypointsJson = row['waypoints_json'] as String?;
      if (waypointsJson != null && waypointsJson.isNotEmpty) {
        jsonMap['waypoints'] = jsonDecode(waypointsJson);
      }
    } catch (e) {
      debugPrint(
        '[RouteStorage] Error decoding waypoints for route ${row['id']}: $e',
      );
      jsonMap['waypoints'] = [];
    }

    return JeepneyRoute.fromJson(jsonMap);
  }
}
